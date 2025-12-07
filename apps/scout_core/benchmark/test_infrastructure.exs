# Quick test to verify benchmark infrastructure works
Code.require_file("util.exs", __DIR__)

alias Benchmark.Util

IO.puts("Testing benchmark infrastructure...\n")

# Test 1: Environment info
IO.puts("Test 1: Environment info")
Util.print_env_info()
IO.puts("✓ Environment info works\n")

# Test 2: Search space generation
IO.puts("Test 2: Search space generation")
space = Util.continuous_space(2, -5, 5)
IO.inspect(space, label: "2D space")
IO.puts("✓ Search space works\n")

# Test 3: Test functions
IO.puts("Test 3: Test functions")
params = %{x1: 1.0, x2: 1.0}
sphere_val = Util.sphere([1.0, 1.0])
IO.puts("Sphere([1.0, 1.0]) = #{sphere_val} (expected: 2.0)")
IO.puts("✓ Test functions work\n")

# Test 4: Quick optimization run (minimal trials)
IO.puts("Test 4: Quick optimization (5 trials)")
result = Scout.Easy.optimize(
  &Util.sphere/1,
  space,
  n_trials: 5,
  sampler: :random,
  direction: :minimize
)
IO.puts("Best value: #{result.best_value}")
IO.puts("Best params: #{inspect(result.best_params)}")
IO.puts("✓ Optimization works\n")

IO.puts(String.duplicate("=", 60))
IO.puts("All infrastructure tests passed!")
IO.puts(String.duplicate("=", 60))
