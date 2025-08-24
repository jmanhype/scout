defmodule Scout.Pruner.ThresholdPruner do
  @moduledoc """
  Prunes trials that don't meet specified thresholds at certain steps.
  
  Equivalent to Optuna's ThresholdPruner. Useful when you have domain knowledge
  about expected performance at specific checkpoints.
  """
  
  @behaviour Scout.Pruner

  # Default implementation for missing callbacks
  def assign_bracket(_trial_index, state), do: {0, state}
  def keep?(_study_id, _trial_id, _bracket, _step, state), do: {true, state}
  
  @default_n_warmup_steps 0
  
  def init(opts \\ %{}) do
    %{
      thresholds: Map.get(opts, :thresholds, %{}),  # Map of step => threshold
      n_warmup_steps: Map.get(opts, :n_warmup_steps, @default_n_warmup_steps),
      direction: Map.get(opts, :direction, :minimize)  # :minimize or :maximize
    }
  end
  
  def should_prune?(_study_id, _trial_id, step, value, state) do
    # Don't prune during warmup
    if step < state.n_warmup_steps do
      {false, state}
    else
      # Check if we have a threshold for this step
      case Map.get(state.thresholds, step) do
        nil ->
          # No threshold for this step
          {false, state}
        
        threshold ->
          # Check if value meets threshold based on direction
          should_prune = case state.direction do
            :minimize -> value > threshold  # Prune if worse than threshold
            :maximize -> value < threshold  # Prune if worse than threshold
          end
          
          {should_prune, state}
      end
    end
  end
  
  @doc """
  Creates a threshold pruner with linear interpolation between specified points.
  
  ## Example
  
      # Define thresholds at specific steps
      Scout.Pruner.ThresholdPruner.with_interpolation(
        [{10, 0.8}, {20, 0.7}, {30, 0.6}],
        direction: :minimize
      )
  """
  def with_interpolation(threshold_points, opts \\ []) do
    # Sort points by step
    sorted_points = Enum.sort_by(threshold_points, &elem(&1, 0))
    
    # Generate interpolated thresholds
    thresholds = generate_interpolated_thresholds(sorted_points)
    
    init(%{
      thresholds: thresholds,
      n_warmup_steps: Keyword.get(opts, :n_warmup_steps, 0),
      direction: Keyword.get(opts, :direction, :minimize)
    })
  end
  
  defp generate_interpolated_thresholds([]), do: %{}
  defp generate_interpolated_thresholds([{step, value}]), do: %{step => value}
  defp generate_interpolated_thresholds(points) do
    points
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.flat_map(fn [{step1, val1}, {step2, val2}] ->
      # Linear interpolation between points
      for s <- step1..step2 do
        if s == step1 do
          {s, val1}
        else
          t = (s - step1) / (step2 - step1)
          {s, val1 + t * (val2 - val1)}
        end
      end
    end)
    |> Enum.into(%{})
  end
  
  @doc """
  Creates a threshold pruner with exponential decay thresholds.
  
  ## Example
  
      # Start at 1.0, decay to 0.1 over 100 steps
      Scout.Pruner.ThresholdPruner.with_exponential_decay(
        initial_threshold: 1.0,
        final_threshold: 0.1,
        decay_steps: 100,
        direction: :minimize
      )
  """
  def with_exponential_decay(opts) do
    initial = Keyword.fetch!(opts, :initial_threshold)
    final = Keyword.fetch!(opts, :final_threshold)
    steps = Keyword.fetch!(opts, :decay_steps)
    direction = Keyword.get(opts, :direction, :minimize)
    n_warmup = Keyword.get(opts, :n_warmup_steps, 0)
    
    # Calculate decay rate
    decay_rate = :math.log(final / initial) / steps
    
    # Generate thresholds
    thresholds = for s <- 1..steps, into: %{} do
      threshold = initial * :math.exp(decay_rate * s)
      {s, threshold}
    end
    
    init(%{
      thresholds: thresholds,
      n_warmup_steps: n_warmup,
      direction: direction
    })
  end
  
  @doc """
  Creates a threshold pruner with step function thresholds.
  
  ## Example
  
      # Different thresholds for different phases
      Scout.Pruner.ThresholdPruner.with_step_function([
        {0, 10, 0.9},   # Steps 0-10: threshold 0.9
        {11, 20, 0.8},  # Steps 11-20: threshold 0.8
        {21, 50, 0.7}   # Steps 21-50: threshold 0.7
      ])
  """
  def with_step_function(ranges, opts \\ []) do
    thresholds = ranges
    |> Enum.flat_map(fn {start_step, end_step, threshold} ->
      for s <- start_step..end_step, do: {s, threshold}
    end)
    |> Enum.into(%{})
    
    init(%{
      thresholds: thresholds,
      n_warmup_steps: Keyword.get(opts, :n_warmup_steps, 0),
      direction: Keyword.get(opts, :direction, :minimize)
    })
  end
end