defmodule Scout.Sampler.MOTPE do
  @behaviour Scout.Sampler
  @moduledoc """
  Multi-objective Tree-structured Parzen Estimator (MOTPE) sampler.
  
  This implementation handles multi-objective optimization where multiple
  objectives need to be optimized simultaneously. Similar to Optuna's
  MOTPESampler.
  
  The sampler uses Pareto dominance to determine which trials are "good"
  and which are "bad" for building the TPE models.
  """
  
  def init(opts) do
    base_state = Scout.Sampler.TPE.init(opts)
    
    Map.merge(base_state, %{
      # Number of objectives to optimize
      n_objectives: Map.get(opts, :n_objectives, 2),
      # Reference point for hypervolume calculation (optional)
      reference_point: Map.get(opts, :reference_point),
      # Whether to use hypervolume or Pareto dominance
      use_hypervolume: Map.get(opts, :use_hypervolume, false),
      # Weights for objectives (for weighted sum approach)
      objective_weights: Map.get(opts, :objective_weights),
      # Scalarization method: "pareto", "weighted_sum", "chebyshev"
      scalarization: Map.get(opts, :scalarization, "pareto")
    })
  end
  
  def next(space_fun, ix, history, state) do
    spec = space_fun.(ix)
    
    if length(history) < state.min_obs do
      # Not enough observations, use random sampling
      Scout.Sampler.RandomSearch.next(space_fun, ix, history, state)
    else
      # Use multi-objective TPE
      sample_motpe(spec, history, state)
    end
  end
  
  # Sample using multi-objective TPE
  defp sample_motpe(spec, history, state) do
    # Convert multi-objective scores based on scalarization method
    scalarized_history = case state.scalarization do
      "pareto" ->
        # Use Pareto dominance to classify good/bad
        classify_by_pareto(history, state.n_objectives)
      
      "weighted_sum" ->
        # Use weighted sum of objectives
        scalarize_weighted_sum(history, state.objective_weights || default_weights(state.n_objectives))
      
      "chebyshev" ->
        # Use Chebyshev scalarization
        scalarize_chebyshev(history, state.reference_point || default_reference(state.n_objectives))
      
      _ ->
        # Default to Pareto
        classify_by_pareto(history, state.n_objectives)
    end
    
    # Use regular TPE with scalarized history
    tpe_state = Map.drop(state, [:n_objectives, :reference_point, :use_hypervolume, 
                                  :objective_weights, :scalarization])
    {params, _} = Scout.Sampler.TPE.next(fn _ -> spec end, 0, scalarized_history, tpe_state)
    
    {params, state}
  end
  
  # Classify trials using Pareto dominance
  defp classify_by_pareto(history, n_objectives) do
    # Extract multi-objective scores
    trials_with_scores = Enum.filter(history, fn trial ->
      is_map(trial.score) and map_size(trial.score) == n_objectives
    end)
    
    if trials_with_scores == [] do
      history
    else
      # Compute Pareto front
      pareto_front = compute_pareto_front(trials_with_scores)
      
      # Convert to single-objective scores
      # Pareto optimal solutions get good scores, dominated get bad scores
      Enum.map(history, fn trial ->
        if trial in pareto_front do
          # Assign good score (negative distance to ideal point)
          ideal_point = compute_ideal_point(trials_with_scores)
          score = -distance_to_point(trial.score, ideal_point)
          %{trial | score: score}
        else
          # Assign bad score (positive distance to nadir point)
          nadir_point = compute_nadir_point(trials_with_scores)
          score = distance_to_point(trial.score, nadir_point)
          %{trial | score: score}
        end
      end)
    end
  end
  
  # Compute Pareto front
  defp compute_pareto_front(trials) do
    Enum.filter(trials, fn trial ->
      not Enum.any?(trials, fn other ->
        other != trial and dominates?(other.score, trial.score)
      end)
    end)
  end
  
  # Check if solution a dominates solution b
  defp dominates?(a, b) when is_map(a) and is_map(b) do
    # Assuming minimization for all objectives
    keys = Map.keys(a)
    
    at_least_one_better = Enum.any?(keys, fn k ->
      Map.get(a, k, 0) < Map.get(b, k, 0)
    end)
    
    none_worse = Enum.all?(keys, fn k ->
      Map.get(a, k, 0) <= Map.get(b, k, 0)
    end)
    
    at_least_one_better and none_worse
  end
  defp dominates?(_, _), do: false
  
  # Compute ideal point (best value for each objective)
  defp compute_ideal_point(trials) do
    objectives = trials
                 |> List.first()
                 |> Map.get(:score)
                 |> Map.keys()
    
    Enum.reduce(objectives, %{}, fn obj, acc ->
      best = trials
             |> Enum.map(fn t -> Map.get(t.score, obj, 0) end)
             |> Enum.min()
      
      Map.put(acc, obj, best)
    end)
  end
  
  # Compute nadir point (worst value for each objective)
  defp compute_nadir_point(trials) do
    objectives = trials
                 |> List.first()
                 |> Map.get(:score)
                 |> Map.keys()
    
    Enum.reduce(objectives, %{}, fn obj, acc ->
      worst = trials
              |> Enum.map(fn t -> Map.get(t.score, obj, 0) end)
              |> Enum.max()
      
      Map.put(acc, obj, worst)
    end)
  end
  
  # Calculate Euclidean distance to a point
  defp distance_to_point(scores, point) when is_map(scores) and is_map(point) do
    keys = Map.keys(point)
    
    sum_sq = Enum.reduce(keys, 0.0, fn k, acc ->
      diff = Map.get(scores, k, 0) - Map.get(point, k, 0)
      acc + diff * diff
    end)
    
    :math.sqrt(sum_sq)
  end
  defp distance_to_point(_, _), do: 0.0
  
  # Scalarize using weighted sum
  defp scalarize_weighted_sum(history, weights) do
    Enum.map(history, fn trial ->
      if is_map(trial.score) do
        score = Enum.reduce(weights, 0.0, fn {obj, weight}, acc ->
          acc + weight * Map.get(trial.score, obj, 0)
        end)
        %{trial | score: score}
      else
        trial
      end
    end)
  end
  
  # Scalarize using Chebyshev method
  defp scalarize_chebyshev(history, reference_point) do
    Enum.map(history, fn trial ->
      if is_map(trial.score) do
        # Chebyshev distance: max of weighted differences
        score = reference_point
                |> Enum.map(fn {obj, ref} ->
                  abs(Map.get(trial.score, obj, 0) - ref)
                end)
                |> Enum.max()
        %{trial | score: score}
      else
        trial
      end
    end)
  end
  
  # Default weights (equal for all objectives)
  defp default_weights(n_objectives) do
    weight = 1.0 / n_objectives
    
    for i <- 0..(n_objectives - 1), into: %{} do
      {:"obj_#{i}", weight}
    end
  end
  
  # Default reference point (zeros)
  defp default_reference(n_objectives) do
    for i <- 0..(n_objectives - 1), into: %{} do
      {:"obj_#{i}", 0.0}
    end
  end
  
  @doc """
  Calculate hypervolume indicator for a set of solutions.
  This is useful for comparing the quality of Pareto fronts.
  """
  def hypervolume(solutions, reference_point) do
    # Simplified 2D hypervolume calculation
    # For production, use a proper hypervolume algorithm
    
    if map_size(reference_point) != 2 do
      # Only support 2D for now
      0.0
    else
      sorted = Enum.sort_by(solutions, fn sol ->
        Map.get(sol, :obj_0, 0)
      end)
      
      hv = 0.0
      prev_x = 0.0
      
      {hv, _} = Enum.reduce(sorted, {hv, prev_x}, fn sol, {acc_hv, prev} ->
        x = Map.get(sol, :obj_0, 0)
        y = Map.get(sol, :obj_1, 0)
        
        ref_x = Map.get(reference_point, :obj_0, 0)
        ref_y = Map.get(reference_point, :obj_1, 0)
        
        if x < ref_x and y < ref_y do
          area = (ref_x - x) * (ref_y - y)
          new_hv = acc_hv + area
          {new_hv, x}
        else
          {acc_hv, prev}
        end
      end)
      
      hv
    end
  end
  
  @doc """
  Convert single-objective trial to multi-objective format.
  """
  def to_multi_objective(trial, objective_extractors) do
    scores = Enum.reduce(objective_extractors, %{}, fn {name, extractor}, acc ->
      Map.put(acc, name, extractor.(trial))
    end)
    
    %{trial | score: scores}
  end
end