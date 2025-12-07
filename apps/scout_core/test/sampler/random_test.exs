defmodule Scout.Sampler.RandomTest do
  use ExUnit.Case, async: false

  alias Scout.Sampler.Random

  describe "init/1" do
    test "initializes with no seed" do
      state = Random.init(%{})
      assert state == %{seed: nil}
    end

    test "initializes with provided seed" do
      state = Random.init(%{seed: 42})
      assert state == %{seed: 42}
    end
  end

  describe "next/4" do
    test "samples uniform parameters" do
      space_fun = fn _ix -> %{x: {:uniform, 0.0, 1.0}} end
      state = Random.init(%{seed: 42})

      {params, new_state} = Random.next(space_fun, 0, [], state)

      assert Map.has_key?(params, :x)
      assert params.x >= 0.0 and params.x <= 1.0
      assert new_state == state
    end

    test "samples log_uniform parameters" do
      space_fun = fn _ix -> %{x: {:log_uniform, 0.1, 100.0}} end
      state = Random.init(%{seed: 42})

      {params, _state} = Random.next(space_fun, 0, [], state)

      assert Map.has_key?(params, :x)
      assert params.x >= 0.1 and params.x <= 100.0
    end

    test "samples integer parameters" do
      space_fun = fn _ix -> %{x: {:int, 1, 10}} end
      state = Random.init(%{seed: 42})

      {params, _state} = Random.next(space_fun, 0, [], state)

      assert Map.has_key?(params, :x)
      assert is_integer(params.x)
      assert params.x >= 1 and params.x <= 10
    end

    test "samples choice parameters" do
      space_fun = fn _ix -> %{x: {:choice, [:a, :b, :c]}} end
      state = Random.init(%{seed: 42})

      {params, _state} = Random.next(space_fun, 0, [], state)

      assert Map.has_key?(params, :x)
      assert params.x in [:a, :b, :c]
    end

    test "samples multiple parameters" do
      space_fun = fn _ix ->
        %{
          x: {:uniform, 0.0, 1.0},
          y: {:int, 1, 5},
          z: {:choice, [:option1, :option2]}
        }
      end

      state = Random.init(%{seed: 42})

      {params, _state} = Random.next(space_fun, 0, [], state)

      assert Map.keys(params) |> Enum.sort() == [:x, :y, :z]
      assert params.x >= 0.0 and params.x <= 1.0
      assert params.y >= 1 and params.y <= 5
      assert params.z in [:option1, :option2]
    end

    test "seeds RNG deterministically when seed provided" do
      space_fun = fn _ix -> %{x: {:uniform, 0.0, 1.0}} end
      state = Random.init(%{seed: 42})

      {params1, _} = Random.next(space_fun, 0, [], state)
      {params2, _} = Random.next(space_fun, 0, [], state)

      # Same seed and index should produce same result
      assert params1.x == params2.x
    end

    test "produces different results for different indices" do
      space_fun = fn _ix -> %{x: {:uniform, 0.0, 1.0}} end
      state = Random.init(%{seed: 42})

      {params1, _} = Random.next(space_fun, 0, [], state)
      {params2, _} = Random.next(space_fun, 1, [], state)

      # Different indices should produce different results
      assert params1.x != params2.x
    end

    test "handles unknown parameter specification with fallback" do
      space_fun = fn _ix -> %{x: {:unknown_type, "some_config"}} end
      state = Random.init(%{seed: 42})

      {params, _state} = Random.next(space_fun, 0, [], state)

      # Fallback should return a random float between 0 and 1
      assert Map.has_key?(params, :x)
      assert is_float(params.x)
      assert params.x >= 0.0 and params.x <= 1.0
    end

    test "works without seed (random sampling)" do
      space_fun = fn _ix -> %{x: {:uniform, 0.0, 1.0}} end
      state = Random.init(%{})

      {params1, _} = Random.next(space_fun, 0, [], state)
      {params2, _} = Random.next(space_fun, 0, [], state)

      # Without seed, should produce different results (high probability)
      # Note: There's a tiny chance they could be the same, but very unlikely
      assert Map.has_key?(params1, :x)
      assert Map.has_key?(params2, :x)
    end

    test "uniform distribution covers full range" do
      space_fun = fn _ix -> %{x: {:uniform, 10.0, 20.0}} end
      state = Random.init(%{})

      # Sample multiple times to check range coverage
      results = for i <- 1..20 do
        {params, _} = Random.next(space_fun, i, [], state)
        params.x
      end

      # All values should be within bounds
      assert Enum.all?(results, fn x -> x >= 10.0 and x <= 20.0 end)

      # Check that we get some variety (not all the same value)
      unique_count = results |> Enum.uniq() |> length()
      assert unique_count > 1
    end

    test "integer distribution covers full range" do
      space_fun = fn _ix -> %{x: {:int, 5, 10}} end
      state = Random.init(%{})

      # Sample multiple times
      results = for i <- 1..30 do
        {params, _} = Random.next(space_fun, i, [], state)
        params.x
      end

      # All values should be within bounds and integers
      assert Enum.all?(results, fn x -> is_integer(x) and x >= 5 and x <= 10 end)

      # Check variety
      unique_count = results |> Enum.uniq() |> length()
      assert unique_count > 1
    end

    test "log_uniform produces log-scaled values" do
      space_fun = fn _ix -> %{x: {:log_uniform, 0.001, 1000.0}} end
      state = Random.init(%{seed: 123})

      results = for i <- 1..20 do
        {params, _} = Random.next(space_fun, i, [], state)
        params.x
      end

      # All values should be within bounds
      assert Enum.all?(results, fn x -> x >= 0.001 and x <= 1000.0 end)

      # Log-uniform should produce values across the log scale
      # Take logarithms and check for distribution
      log_results = Enum.map(results, &:math.log/1)
      min_log = Enum.min(log_results)
      max_log = Enum.max(log_results)

      # Should span a reasonable portion of the log range
      range = max_log - min_log
      assert range > 2.0  # At least e^2 ≈ 7.4x spread
    end

    test "choice samples all options eventually" do
      space_fun = fn _ix -> %{x: {:choice, [:a, :b, :c, :d, :e]}} end
      state = Random.init(%{})

      # Sample many times
      results = for i <- 1..50 do
        {params, _} = Random.next(space_fun, i, [], state)
        params.x
      end

      # Should see multiple different choices
      unique_choices = results |> Enum.uniq()
      assert length(unique_choices) >= 3  # At least 3 out of 5 options
    end
  end
end
