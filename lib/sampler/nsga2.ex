defmodule Scout.Sampler.NSGA2 do
  @moduledoc """
  NSGA-II (Non-dominated Sorting Genetic Algorithm II) for multi-objective optimization.
  
  Implements the NSGA-II algorithm with:
  - Non-dominated sorting
  - Crowding distance calculation
  - Tournament selection
  - Crossover and mutation operators
  - Constraint handling
  
  Based on Deb et al. (2002) "A Fast and Elitist Multiobjective Genetic Algorithm: NSGA-II"
  """
  
  @behaviour Scout.Sampler
  
  @default_population_size 50
  @default_mutation_prob 0.1
  @default_crossover_prob 0.9
  @default_eta_crossover 20
  @default_eta_mutation 20
  
  @impl true
  def init(opts) do
    %{
      population_size: Map.get(opts, :population_size, @default_population_size),
      mutation_prob: Map.get(opts, :mutation_prob, @default_mutation_prob),
      crossover_prob: Map.get(opts, :crossover_prob, @default_crossover_prob),
      eta_crossover: Map.get(opts, :eta_crossover, @default_eta_crossover),
      eta_mutation: Map.get(opts, :eta_mutation, @default_eta_mutation),
      constraints_func: Map.get(opts, :constraints_func),
      population: [],
      generation: 0,
      seed: Map.get(opts, :seed)
    }
  end
  
  @impl true
  def next(space_fun, ix, history, state) do
    # Set random seed if provided
    if state.seed do
      :rand.seed(:exsplus, {state.seed, ix, state.generation})
    end
    
    # Get search space
    spec = space_fun.(ix)
    
    # Initialize population on first call
    state = if state.population == [] do
      population = initialize_population(spec, state.population_size)
      %{state | population: population}
    else
      state
    end
    
    # Evolve population if we have enough history
    state = if length(history) >= state.population_size do
      state = evolve_population(state, history, spec)
      %{state | generation: state.generation + 1}
    else
      state
    end
    
    # Select next individual to evaluate
    individual = select_next_individual(state.population, ix)
    params = decode_individual(individual, spec)
    
    {params, state}
  end
  
  # Initialize random population
  defp initialize_population(spec, size) do
    for _ <- 1..size do
      for {param_name, param_spec} <- spec, into: %{} do
        value = sample_parameter(param_spec)
        {param_name, encode_value(value, param_spec)}
      end
    end
  end
  
  # Evaluate population fitness from history
  defp evaluate_population(population, history) do
    Enum.map(population, fn individual ->
      # Find matching trial in history
      matching_trial = Enum.find(history, fn trial ->
        trial.params == individual[:params]
      end)
      
      if matching_trial do
        Map.put(individual, :fitness, matching_trial.score)
      else
        # If not in history, needs evaluation
        individual
      end
    end)
  end
  
  # Evolve population using NSGA-II
  defp evolve_population(state, history, spec) do
    # Evaluate fitness for current population
    evaluated_pop = evaluate_population(state.population, history)
    
    # Non-dominated sorting
    fronts = non_dominated_sort(evaluated_pop, state.constraints_func)
    
    # Calculate crowding distance
    fronts_with_distance = Enum.map(fronts, &assign_crowding_distance/1)
    
    # Create offspring through crossover and mutation
    offspring = create_offspring(fronts_with_distance, spec, state)
    
    # Combine parent and offspring populations
    combined = evaluated_pop ++ offspring
    
    # Select next generation using elitism
    next_pop = environmental_selection(combined, state.population_size, state.constraints_func)
    
    %{state | population: next_pop}
  end
  
  # Non-dominated sorting
  defp non_dominated_sort(population, constraints_func) do
    # Calculate domination relationships
    domination_info = calculate_domination(population, constraints_func)
    
    # Sort into fronts
    fronts = []
    current_front = find_non_dominated(population, domination_info)
    remaining = population -- current_front
    
    sort_into_fronts(current_front, remaining, domination_info, fronts)
  end
  
  defp calculate_domination(population, constraints_func) do
    for p1 <- population, into: %{} do
      dominated_by = for p2 <- population, p2 != p1, dominates?(p2, p1, constraints_func), do: p2
      dominates_set = for p2 <- population, p2 != p1, dominates?(p1, p2, constraints_func), do: p2
      
      {p1, %{dominated_by: dominated_by, dominates: dominates_set}}
    end
  end
  
  defp dominates?(p1, p2, constraints_func) do
    # Handle constraints if provided
    if constraints_func do
      c1 = constraints_func.(p1)
      c2 = constraints_func.(p2)
      
      # Constraint violation dominance
      v1 = constraint_violation(c1)
      v2 = constraint_violation(c2)
      
      cond do
        v1 < v2 -> true
        v1 > v2 -> false
        true -> objective_dominates?(p1.objectives, p2.objectives)
      end
    else
      objective_dominates?(p1.objectives, p2.objectives)
    end
  end
  
  defp objective_dominates?(obj1, obj2) do
    # Check Pareto dominance for minimization
    all_not_worse = Enum.zip(obj1, obj2) |> Enum.all?(fn {o1, o2} -> o1 <= o2 end)
    at_least_one_better = Enum.zip(obj1, obj2) |> Enum.any?(fn {o1, o2} -> o1 < o2 end)
    
    all_not_worse and at_least_one_better
  end
  
  defp constraint_violation(constraints) when is_list(constraints) do
    # Sum of constraint violations (constraints <= 0 are feasible)
    constraints
    |> Enum.map(&max(&1, 0))
    |> Enum.sum()
  end
  defp constraint_violation(_), do: 0
  
  defp find_non_dominated(population, domination_info) do
    Enum.filter(population, fn p ->
      domination_info[p].dominated_by == []
    end)
  end
  
  defp sort_into_fronts([], _, _, fronts), do: Enum.reverse(fronts)
  defp sort_into_fronts(current_front, [], _, fronts) do
    Enum.reverse([current_front | fronts])
  end
  defp sort_into_fronts(current_front, remaining, domination_info, fronts) do
    next_front = find_next_front(current_front, remaining, domination_info)
    new_remaining = remaining -- next_front
    sort_into_fronts(next_front, new_remaining, domination_info, [current_front | fronts])
  end
  
  defp find_next_front(current_front, remaining, domination_info) do
    Enum.filter(remaining, fn p ->
      dominated_by = domination_info[p].dominated_by
      Enum.all?(dominated_by, fn dom -> dom in current_front end)
    end)
  end
  
  # Assign crowding distance for diversity preservation
  defp assign_crowding_distance(front) when length(front) <= 2 do
    # Edge individuals get infinite distance
    Enum.map(front, fn ind -> Map.put(ind, :crowding_distance, :infinity) end)
  end
  
  defp assign_crowding_distance(front) do
    n_objectives = length(hd(front).objectives)
    
    # Initialize distances
    front_with_dist = Enum.map(front, fn ind -> Map.put(ind, :crowding_distance, 0) end)
    
    # Calculate distance for each objective
    Enum.reduce(0..(n_objectives - 1), front_with_dist, fn obj_idx, acc ->
      # Sort by this objective
      sorted = Enum.sort_by(acc, fn ind -> Enum.at(ind.objectives, obj_idx) end)
      
      # Set boundary distances
      sorted = List.update_at(sorted, 0, &Map.put(&1, :crowding_distance, :infinity))
      sorted = List.update_at(sorted, -1, &Map.put(&1, :crowding_distance, :infinity))
      
      # Calculate distances for interior points
      if length(sorted) > 2 do
        obj_range = Enum.at(List.last(sorted).objectives, obj_idx) - 
                   Enum.at(hd(sorted).objectives, obj_idx)
        
        if obj_range > 0 do
          Enum.with_index(sorted)
          |> Enum.slice(1..-2//1)
          |> Enum.map(fn {ind, i} ->
            if ind.crowding_distance != :infinity do
              prev_obj = Enum.at(Enum.at(sorted, i - 1).objectives, obj_idx)
              next_obj = Enum.at(Enum.at(sorted, i + 1).objectives, obj_idx)
              dist_add = (next_obj - prev_obj) / obj_range
              Map.update!(ind, :crowding_distance, &(&1 + dist_add))
            else
              ind
            end
          end)
        else
          sorted
        end
      else
        sorted
      end
    end)
  end
  
  # Create offspring through genetic operators
  defp create_offspring(fronts, spec, state) do
    # Flatten fronts for selection
    population = List.flatten(fronts)
    offspring_size = state.population_size
    
    for _ <- 1..offspring_size do
      # Tournament selection
      parent1 = tournament_selection(population)
      parent2 = tournament_selection(population)
      
      # Crossover
      child = if :rand.uniform() < state.crossover_prob do
        sbx_crossover(parent1, parent2, spec, state.eta_crossover)
      else
        parent1
      end
      
      # Mutation
      if :rand.uniform() < state.mutation_prob do
        polynomial_mutation(child, spec, state.eta_mutation)
      else
        child
      end
    end
  end
  
  # Binary tournament selection based on rank and crowding distance
  defp tournament_selection(population) do
    p1 = Enum.random(population)
    p2 = Enum.random(population)
    
    cond do
      p1.rank < p2.rank -> p1
      p2.rank < p1.rank -> p2
      p1.crowding_distance == :infinity -> p1
      p2.crowding_distance == :infinity -> p2
      p1.crowding_distance > p2.crowding_distance -> p1
      true -> p2
    end
  end
  
  # Simulated Binary Crossover (SBX)
  defp sbx_crossover(parent1, parent2, spec, eta) do
    for {param_name, param_spec} <- spec, into: %{} do
      p1_val = Map.get(parent1, param_name)
      p2_val = Map.get(parent2, param_name)
      
      child_val = case param_spec do
        {:uniform, min, max} ->
          sbx_real(p1_val, p2_val, min, max, eta)
        {:int, min, max} ->
          round(sbx_real(p1_val, p2_val, min, max, eta))
        {:choice, _} ->
          if :rand.uniform() < 0.5, do: p1_val, else: p2_val
        _ ->
          p1_val
      end
      
      {param_name, child_val}
    end
  end
  
  defp sbx_real(p1, p2, min, max, eta) do
    if abs(p1 - p2) < 1.0e-14 do
      p1
    else
      y1 = min(p1, p2)
      y2 = max(p1, p2)
      
      rand = :rand.uniform()
      beta = if rand <= 0.5 do
        :math.pow(2 * rand, 1.0 / (eta + 1))
      else
        :math.pow(1.0 / (2 * (1 - rand)), 1.0 / (eta + 1))
      end
      
      c1 = 0.5 * ((y1 + y2) - beta * (y2 - y1))
      c2 = 0.5 * ((y1 + y2) + beta * (y2 - y1))
      
      child = if :rand.uniform() < 0.5, do: c1, else: c2
      max(min, min(max, child))
    end
  end
  
  # Polynomial mutation
  defp polynomial_mutation(individual, spec, eta) do
    for {param_name, param_spec} <- spec, into: %{} do
      val = Map.get(individual, param_name)
      
      mutated = case param_spec do
        {:uniform, min, max} ->
          polynomial_mutate_real(val, min, max, eta)
        {:int, min, max} ->
          round(polynomial_mutate_real(val, min, max, eta))
        {:choice, choices} ->
          if :rand.uniform() < 0.1, do: Enum.random(choices), else: val
        _ ->
          val
      end
      
      {param_name, mutated}
    end
  end
  
  defp polynomial_mutate_real(val, min, max, eta) do
    if :rand.uniform() < 0.5 do
      val
    else
      delta = if :rand.uniform() < 0.5 do
        d = (val - min) / (max - min)
        :math.pow(2 * :rand.uniform() * d, 1.0 / (eta + 1)) - 1
      else
        d = (max - val) / (max - min)
        1 - :math.pow(2 * :rand.uniform() * d, 1.0 / (eta + 1))
      end
      
      max(min, min(max, val + delta * (max - min)))
    end
  end
  
  # Environmental selection using elitism
  defp environmental_selection(combined, pop_size, constraints_func) do
    # Non-dominated sort of combined population
    fronts = non_dominated_sort(combined, constraints_func)
    
    _selected = []
    remaining_slots = pop_size
    
    # Add complete fronts that fit
    {selected, _remaining_slots} = Enum.reduce_while(fronts, {[], remaining_slots}, fn front, {sel, slots} ->
      if length(front) <= slots do
        {:cont, {sel ++ front, slots - length(front)}}
      else
        # Need to select from this front based on crowding distance
        front_with_dist = assign_crowding_distance(front)
        sorted = Enum.sort_by(front_with_dist, & &1.crowding_distance, :desc)
        selected_from_front = Enum.take(sorted, slots)
        {:halt, {sel ++ selected_from_front, 0}}
      end
    end)
    
    selected
  end
  
  # Select next individual to evaluate
  defp select_next_individual(population, ix) do
    # Round-robin through population
    idx = rem(ix, length(population))
    Enum.at(population, idx)
  end
  
  # Helper functions
  defp sample_parameter({:uniform, min, max}) do
    min + :rand.uniform() * (max - min)
  end
  
  defp sample_parameter({:int, min, max}) do
    min + :rand.uniform(max - min + 1) - 1
  end
  
  defp sample_parameter({:choice, choices}) do
    Enum.random(choices)
  end
  
  defp sample_parameter({:log_uniform, min, max}) do
    log_min = :math.log(min)
    log_max = :math.log(max)
    :math.exp(log_min + :rand.uniform() * (log_max - log_min))
  end
  
  defp encode_value(value, _spec), do: value
  
  defp decode_individual(individual, spec) do
    for {param_name, _param_spec} <- spec, into: %{} do
      {param_name, Map.get(individual, param_name)}
    end
  end
end