defmodule Scout.Sampler.ConstantLiarTPE do
  @behaviour Scout.Sampler
  @moduledoc """
  TPE sampler with Constant Liar strategy for distributed optimization.
  
  When multiple trials are running in parallel, assumes pending trials
  will achieve a constant value (e.g., mean of completed trials).
  This prevents multiple workers from exploring the same region.
  
  Similar to Optuna's TPESampler(constant_liar=True).
  """
  
  def init(opts) do
    base_state = Scout.Sampler.TPE.init(opts)
    
    Map.merge(base_state, %{
      constant_liar: Map.get(opts, :constant_liar, true),
      liar_strategy: Map.get(opts, :liar_strategy, :mean),  # :mean, :median, :best, :worst
      pending_trials: Map.get(opts, :pending_trials, [])
    })
  end
  
  def next(space_fun, ix, history, state) do
    if not state.constant_liar do
      # Fallback to regular TPE
      Scout.Sampler.TPE.next(space_fun, ix, history, state)
    else
      # Include pending trials with assumed values
      augmented_history = augment_with_pending(history, state)
      
      # Use TPE with augmented history
      {params, new_tpe_state} = Scout.Sampler.TPE.next(
        space_fun,
        ix,
        augmented_history,
        Map.drop(state, [:pending_trials, :constant_liar, :liar_strategy])
      )
      
      # Update state with new pending trial
      new_pending = %{
        params: params,
        score: calculate_liar_value(history, state),
        status: :pending,
        id: "pending-#{ix}"
      }
      
      new_state = Map.merge(state, %{
        pending_trials: state.pending_trials ++ [new_pending]
      })
      
      {params, Map.merge(new_state, new_tpe_state)}
    end
  end
  
  # Add pending trials with assumed scores
  defp augment_with_pending(history, state) do
    if Enum.empty?(state.pending_trials) do
      history
    else
      liar_value = calculate_liar_value(history, state)
      
      fake_trials = Enum.map(state.pending_trials, fn pending ->
        %Scout.Trial{
          id: pending.id,
          study_id: "constant-liar-study",  # Placeholder study ID
          params: pending.params,
          score: liar_value,
          status: :succeeded,
          bracket: 0
        }
      end)
      
      history ++ fake_trials
    end
  end
  
  # Calculate the constant liar value based on strategy
  defp calculate_liar_value(history, state) do
    completed = Enum.filter(history, fn t -> 
      t.status == :succeeded and is_number(t.score)
    end)
    
    if Enum.empty?(completed) do
      # No completed trials yet, return neutral value
      0.0
    else
      scores = Enum.map(completed, & &1.score)
      
      case state.liar_strategy do
        :mean ->
          Enum.sum(scores) / length(scores)
          
        :median ->
          sorted = Enum.sort(scores)
          n = length(sorted)
          if rem(n, 2) == 0 do
            (Enum.at(sorted, div(n, 2) - 1) + Enum.at(sorted, div(n, 2))) / 2
          else
            Enum.at(sorted, div(n, 2))
          end
          
        :best ->
          case state.goal do
            :minimize -> Enum.min(scores)
            _ -> Enum.max(scores)
          end
          
        :worst ->
          case state.goal do
            :minimize -> Enum.max(scores)
            _ -> Enum.min(scores)
          end
          
        value when is_number(value) ->
          # Custom constant value
          value
          
        _ ->
          # Default to mean
          Enum.sum(scores) / length(scores)
      end
    end
  end
  
  # Update pending trials when a trial completes
  def update_pending(state, completed_trial_id) do
    new_pending = Enum.reject(state.pending_trials, fn p ->
      p.id == completed_trial_id
    end)
    
    Map.put(state, :pending_trials, new_pending)
  end
  
  # Clear all pending trials (e.g., when study completes)
  def clear_pending(state) do
    Map.put(state, :pending_trials, [])
  end
end