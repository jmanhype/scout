defmodule Scout.Sampler.QMC do
  @moduledoc """
  Quasi-Monte Carlo sampler using low-discrepancy sequences.
  
  Implements Sobol and Halton sequences for better space coverage than random sampling.
  Equivalent to Optuna's QMCSampler and useful for initial exploration.
  """
  
  @behaviour Scout.Sampler
  import Bitwise
  
  @default_sequence :sobol
  @default_scramble true
  @default_seed nil
  
  def init(opts \\ %{}) do
    %{
      sequence: Map.get(opts, :sequence, @default_sequence),
      scramble: Map.get(opts, :scramble, @default_scramble),
      seed: Map.get(opts, :seed, @default_seed),
      dimension_counters: %{},
      sobol_directions: nil,
      halton_bases: nil
    }
    |> initialize_sequence()
  end
  
  def next(space_fun, ix, _history, state) do
    # Set random seed if provided (for scrambling)
    if state.seed && state.scramble do
      :rand.seed(:exsplus, {state.seed, ix, 0})
    end
    
    # Get search space
    spec = space_fun.(ix)
    dim = map_size(spec)
    
    # Generate next point in sequence
    point = case state.sequence do
      :sobol -> sobol_point(ix, dim, state)
      :halton -> halton_point(ix, dim, state)
      :latin_hypercube -> latin_hypercube_point(ix, dim, state)
    end
    
    # Map to parameter space
    params = decode_point(point, spec)
    
    {params, state}
  end
  
  defp initialize_sequence(state) do
    case state.sequence do
      :sobol ->
        %{state | sobol_directions: initialize_sobol_directions()}
      :halton ->
        %{state | halton_bases: generate_prime_bases()}
      _ ->
        state
    end
  end
  
  # Sobol sequence implementation
  
  defp sobol_point(index, dim, state) do
    # Skip first point (all zeros) by using index + 1
    n = index + 1
    
    for d <- 0..(dim-1) do
      # Get direction numbers for this dimension
      directions = get_sobol_directions(d, state.sobol_directions)
      
      # Generate Sobol point
      value = sobol_generate(n, directions)
      
      # Apply scrambling if enabled
      if state.scramble do
        scramble_value(value)
      else
        value
      end
    end
  end
  
  defp sobol_generate(n, directions) do
    # Gray code of n
    gray = bxor(n, bsr(n, 1))
    
    # Find position of rightmost zero bit in n-1
    value = 0.0
    mask = 1
    
    {result, _} = Enum.reduce_while(0..31, {value, mask}, fn i, {acc, current_mask} ->
      if band(gray, current_mask) != 0 do
        direction = Enum.at(directions, i, 0)
        new_acc = bxor(trunc(acc * :math.pow(2, 32)), direction) / :math.pow(2, 32)
        {:cont, {new_acc, bsl(current_mask, 1)}}
      else
        {:cont, {acc, bsl(current_mask, 1)}}
      end
    end)
    result
  end
  
  defp initialize_sobol_directions() do
    # Simplified Sobol direction numbers (first 8 dimensions)
    # In production, would load from file or generate properly
    %{
      0 => [1 | List.duplicate(1, 31)],
      1 => [1, 3, 7, 15, 31, 63, 127, 255, 511, 1023, 2047, 4095, 8191, 16383, 32767, 65535,
            131071, 262143, 524287, 1048575, 2097151, 4194303, 8388607, 16777215, 33554431,
            67108863, 134217727, 268435455, 536870911, 1073741823, 2147483647, 4294967295],
      2 => [1, 3, 1, 3, 1, 3, 1, 3, 1, 3, 1, 3, 1, 3, 1, 3,
            1, 3, 1, 3, 1, 3, 1, 3, 1, 3, 1, 3, 1, 3, 1, 3],
      3 => [1, 1, 7, 11, 13, 19, 25, 37, 59, 47, 61, 55, 41, 67, 97, 91,
            109, 103, 115, 131, 193, 137, 145, 143, 241, 157, 185, 167, 229, 171, 213, 191]
    }
  end
  
  defp get_sobol_directions(dim, directions) do
    Map.get(directions, dim, generate_direction_numbers(dim))
  end
  
  defp generate_direction_numbers(dim) do
    # Generate direction numbers using primitive polynomials
    # This is a simplified version
    :rand.seed(:exsplus, {dim, dim * 1000, dim * 10000})
    
    for i <- 0..31 do
      :rand.uniform(trunc(:math.pow(2, i + 1))) - 1
    end
  end
  
  # Halton sequence implementation
  
  defp halton_point(index, dim, state) do
    bases = state.halton_bases || generate_prime_bases()
    
    for d <- 0..(dim-1) do
      base = Enum.at(bases, d, nth_prime(d + 2))
      value = halton_generate(index + 1, base)
      
      if state.scramble do
        scramble_value(value)
      else
        value
      end
    end
  end
  
  defp halton_generate(n, base) do
    result = 0.0
    f = 1.0 / base
    i = n
    
    {result, _} = Enum.reduce_while(1..100, {result, {f, i}}, fn _, {acc, {f_val, i_val}} ->
      if i_val > 0 do
        digit = rem(i_val, base)
        new_acc = acc + digit * f_val
        new_f = f_val / base
        new_i = div(i_val, base)
        {:cont, {new_acc, {new_f, new_i}}}
      else
        {:halt, {acc, {f_val, i_val}}}
      end
    end)
    
    result
  end
  
  defp generate_prime_bases() do
    # First 50 prime numbers for up to 50 dimensions
    [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71,
     73, 79, 83, 89, 97, 101, 103, 107, 109, 113, 127, 131, 137, 139, 149, 151,
     157, 163, 167, 173, 179, 181, 191, 193, 197, 199, 211, 223, 227, 229]
  end
  
  defp nth_prime(n) do
    # Simple prime generator for small n
    primes = generate_prime_bases()
    Enum.at(primes, n - 1, n * 6 - 1)  # Approximation for larger n
  end
  
  # Latin Hypercube Sampling
  
  defp latin_hypercube_point(index, dim, state) do
    # For LHS, we need to pre-generate the full design
    # This is a simplified version that generates points on-the-fly
    
    for d <- 0..(dim-1) do
      # Stratified sampling in each dimension
      n_strata = 100  # Number of strata
      stratum = rem(index, n_strata)
      
      # Random point within stratum
      base = stratum / n_strata
      width = 1.0 / n_strata
      
      value = base + :rand.uniform() * width
      
      if state.scramble do
        # Permute strata
        permuted_stratum = rem(stratum * 31 + d * 17, n_strata)
        permuted_base = permuted_stratum / n_strata
        permuted_base + :rand.uniform() * width
      else
        value
      end
    end
  end
  
  # Scrambling for better randomization
  
  defp scramble_value(value) do
    # Owen scrambling
    # Simplified version using random permutation
    scrambled = value * 0.9998 + :rand.uniform() * 0.0002
    min(0.9999, max(0.0001, scrambled))
  end
  
  # Decode point to parameters
  
  defp decode_point(point, spec) do
    spec
    |> Enum.zip(point)
    |> Enum.map(fn {{param_name, param_spec}, value} ->
      decoded = case param_spec do
        {:uniform, min, max} ->
          min + value * (max - min)
          
        {:log_uniform, min, max} ->
          log_min = :math.log(min)
          log_max = :math.log(max)
          :math.exp(log_min + value * (log_max - log_min))
          
        {:int, min, max} ->
          # Map to discrete values
          n_values = max - min + 1
          idx = min(trunc(value * n_values), n_values - 1)
          min + idx
          
        {:choice, choices} ->
          # Map to categorical
          n_choices = length(choices)
          idx = min(trunc(value * n_choices), n_choices - 1)
          Enum.at(choices, idx)
      end
      
      {param_name, decoded}
    end)
    |> Enum.into(%{})
  end
  
  @doc """
  Generates a batch of QMC points for parallel evaluation.
  """
  def generate_batch(space_fun, start_index, batch_size, state) do
    for i <- start_index..(start_index + batch_size - 1) do
      {params, _} = next(space_fun, i, [], state)
      params
    end
  end
  
  @doc """
  Computes discrepancy measure for a set of points.
  Lower discrepancy means better space coverage.
  """
  def discrepancy(points) do
    n = length(points)
    dim = length(hd(points))
    
    # Star discrepancy approximation
    max_disc = 0.0
    
    # Sample test boxes
    n_tests = min(100, n * 10)
    
    Enum.reduce(1..n_tests, max_disc, fn _, acc ->
      # Random test box
      corner = for _ <- 1..dim, do: :rand.uniform()
      
      # Count points in box
      count = Enum.count(points, fn point ->
        Enum.zip(point, corner)
        |> Enum.all?(fn {p, c} -> p <= c end)
      end)
      
      # Expected vs actual
      expected = Enum.reduce(corner, 1.0, &(&1 * &2)) * n
      disc = abs(count - expected) / n
      
      max(acc, disc)
    end)
  end
  
  @doc """
  Optimizes QMC sequence parameters for a specific problem.
  """
  def optimize_sequence(objective_fn, space_spec, n_trials) do
    sequences = [:sobol, :halton, :latin_hypercube]
    
    results = for seq <- sequences do
      state = init(%{sequence: seq, scramble: true})
      
      # Run trials
      values = for i <- 0..(n_trials-1) do
        {params, _} = next(fn _ -> space_spec end, i, [], state)
        objective_fn.(params)
      end
      
      # Calculate statistics
      mean = Enum.sum(values) / length(values)
      std = :math.sqrt(
        Enum.sum(Enum.map(values, fn v -> :math.pow(v - mean, 2) end)) / length(values)
      )
      
      %{
        sequence: seq,
        mean: mean,
        std: std,
        best: Enum.min(values)
      }
    end
    
    # Return best sequence based on mean performance
    Enum.min_by(results, & &1.mean)
  end
end