defmodule Scout.Sampler.Grid do
  @moduledoc """
  Grid search sampler that exhaustively tries all combinations of parameters.
  
  ## Options
  
    * `:grid_points` - Number of points to sample for continuous parameters (default: 10)
    * `:shuffle` - Whether to shuffle the grid points (default: false)
  
  ## Example
  
      sampler: Scout.Sampler.Grid,
      sampler_opts: %{
        grid_points: 5,
        shuffle: true
      }
  """
  
  @behaviour Scout.Sampler
  
  @doc """
  Initialize grid search state.
  """
  def init(opts \\ %{}) do
    %{
      grid_points: Map.get(opts, :grid_points, 10),
      shuffle: Map.get(opts, :shuffle, false),
      grid: nil,
      index: 0
    }
  end
  
  @doc """
  Get next point from the grid.
  """
  def next(space_fun, ix, _history, state) do
    space = space_fun.(ix)
    
    # Build grid on first call
    {grid, state} = if state.grid == nil do
      grid = build_grid(space, state.grid_points)
      grid = if state.shuffle do
        Enum.shuffle(grid)
      else
        grid
      end
      {grid, Map.put(state, :grid, grid)}
    else
      {state.grid, state}
    end
    
    # Get next point from grid, cycling if necessary
    index = rem(state.index, length(grid))
    params = Enum.at(grid, index)
    
    new_state = Map.put(state, :index, state.index + 1)
    
    {params, new_state}
  end
  
  # Build the grid of all parameter combinations
  defp build_grid(space, grid_points) do
    param_grids = 
      space
      |> Enum.map(fn {key, spec} ->
        values = discretize_parameter(spec, grid_points)
        {key, values}
      end)
    
    # Generate all combinations
    generate_combinations(param_grids)
  end
  
  # Discretize a single parameter based on its type
  defp discretize_parameter(spec, n_points) do
    case spec do
      {:uniform, min, max} ->
        if n_points == 1 do
          [(min + max) / 2]
        else
          step = (max - min) / (n_points - 1)
          Enum.map(0..(n_points - 1), fn i -> min + i * step end)
        end
        
      {:log_uniform, min, max} ->
        log_min = :math.log(min)
        log_max = :math.log(max)
        if n_points == 1 do
          [:math.exp((log_min + log_max) / 2)]
        else
          step = (log_max - log_min) / (n_points - 1)
          Enum.map(0..(n_points - 1), fn i -> 
            :math.exp(log_min + i * step)
          end)
        end
        
      {:int, min, max} ->
        range = max - min + 1
        if range <= n_points do
          Enum.to_list(min..max)
        else
          # Sample evenly from the range
          step = range / n_points
          Enum.map(0..(n_points - 1), fn i ->
            round(min + i * step)
          end)
          |> Enum.uniq()
        end
        
      {:choice, choices} ->
        choices
        
      {:discrete_uniform, low, high, step} ->
        # Generate all discrete points
        n_steps = trunc((high - low) / step)
        Enum.map(0..n_steps, fn i -> low + i * step end)
        
      _ ->
        # For unknown types, sample randomly
        [Scout.SearchSpace.sample(%{tmp: spec})[:tmp]]
    end
  end
  
  # Generate all combinations of parameter values
  defp generate_combinations(param_grids) do
    param_grids
    |> Enum.reduce([%{}], fn {key, values}, acc ->
      Enum.flat_map(acc, fn combo ->
        Enum.map(values, fn value ->
          Map.put(combo, key, value)
        end)
      end)
    end)
  end
end