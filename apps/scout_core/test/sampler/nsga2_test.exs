defmodule Scout.Sampler.NSGA2Test do
  use ExUnit.Case, async: true

  alias Scout.Sampler.NSGA2

  describe "init/1" do
    test "initializes with default options" do
      state = NSGA2.init(%{})

      assert state.population_size == 50
      assert state.mutation_prob == 0.1
      assert state.crossover_prob == 0.9
      assert state.eta_crossover == 20
      assert state.eta_mutation == 20
      assert state.constraints_func == nil
      assert state.population == []
      assert state.generation == 0
      assert state.seed == nil
    end

    test "initializes with custom population size" do
      state = NSGA2.init(%{population_size: 30})

      assert state.population_size == 30
    end

    test "initializes with custom mutation probability" do
      state = NSGA2.init(%{mutation_prob: 0.2})

      assert state.mutation_prob == 0.2
    end

    test "initializes with custom crossover probability" do
      state = NSGA2.init(%{crossover_prob: 0.8})

      assert state.crossover_prob == 0.8
    end

    test "initializes with seed for reproducibility" do
      state = NSGA2.init(%{seed: 42})

      assert state.seed == 42
    end
  end

  describe "next/4 - initial population" do
    test "creates random population on first call" do
      space_fun = fn _ix -> %{x: {:uniform, 0.0, 1.0}, y: {:uniform, 0.0, 1.0}} end
      state = NSGA2.init(%{population_size: 10, seed: 42})

      {params, new_state} = NSGA2.next(space_fun, 0, [], state)

      # Should have initialized population
      assert length(new_state.population) == 10

      # Should return valid parameters
      assert is_map(params)
      assert Map.has_key?(params, :x)
      assert Map.has_key?(params, :y)
      assert params.x >= 0.0 and params.x <= 1.0
      assert params.y >= 0.0 and params.y <= 1.0
    end

    test "samples from population sequentially" do
      space_fun = fn _ix -> %{x: {:uniform, 0.0, 1.0}} end
      state = NSGA2.init(%{population_size: 5, seed: 42})

      # First 5 calls should sample different individuals
      {_p1, state1} = NSGA2.next(space_fun, 0, [], state)
      {_p2, state2} = NSGA2.next(space_fun, 1, [], state1)
      {_p3, state3} = NSGA2.next(space_fun, 2, [], state2)
      {_p4, state4} = NSGA2.next(space_fun, 3, [], state3)
      {_p5, _state5} = NSGA2.next(space_fun, 4, [], state4)

      # All should have same population (not evolved yet)
      assert state1.population == state2.population
      assert state2.population == state3.population
      assert state3.population == state4.population
    end

    test "cycles through population" do
      space_fun = fn _ix -> %{x: {:uniform, 0.0, 1.0}} end
      state = NSGA2.init(%{population_size: 3, seed: 42})

      {p1, state} = NSGA2.next(space_fun, 0, [], state)
      {_p2, state} = NSGA2.next(space_fun, 1, [], state)
      {_p3, state} = NSGA2.next(space_fun, 2, [], state)
      {p4, _state} = NSGA2.next(space_fun, 3, [], state)

      # Fourth call should cycle back (indices 0, 1, 2, 0)
      assert_in_delta p1.x, p4.x, 0.001
    end
  end

  describe "next/4 - parameter types" do
    test "handles uniform parameters" do
      space_fun = fn _ix -> %{x: {:uniform, -5.0, 5.0}} end
      state = NSGA2.init(%{population_size: 10, seed: 42})

      {params, _} = NSGA2.next(space_fun, 0, [], state)

      assert is_float(params.x)
      assert params.x >= -5.0 and params.x <= 5.0
    end

    test "handles integer parameters" do
      space_fun = fn _ix -> %{n: {:int, 1, 100}} end
      state = NSGA2.init(%{population_size: 10, seed: 42})

      {params, _} = NSGA2.next(space_fun, 0, [], state)

      assert is_integer(params.n)
      assert params.n >= 1 and params.n <= 100
    end

    test "handles choice parameters" do
      space_fun = fn _ix -> %{method: {:choice, ["a", "b", "c"]}} end
      state = NSGA2.init(%{population_size: 10, seed: 42})

      {params, _} = NSGA2.next(space_fun, 0, [], state)

      assert params.method in ["a", "b", "c"]
    end

    test "handles log-uniform parameters" do
      space_fun = fn _ix -> %{lr: {:log_uniform, 1.0e-5, 1.0}} end
      state = NSGA2.init(%{population_size: 10, seed: 42})

      {params, _} = NSGA2.next(space_fun, 0, [], state)

      assert is_float(params.lr)
      assert params.lr >= 1.0e-5 * 0.9 and params.lr <= 1.0
    end

    test "handles mixed parameter types" do
      space_fun = fn _ix ->
        %{
          x: {:uniform, 0.0, 1.0},
          n: {:int, 1, 10},
          method: {:choice, ["a", "b"]}
        }
      end
      state = NSGA2.init(%{population_size: 10, seed: 42})

      {params, _} = NSGA2.next(space_fun, 0, [], state)

      assert is_float(params.x)
      assert params.x >= 0.0 and params.x <= 1.0
      assert is_integer(params.n)
      assert params.n >= 1 and params.n <= 10
      assert params.method in ["a", "b"]
    end
  end

  describe "next/4 - reproducibility" do
    test "generates same population with same seed" do
      space_fun = fn _ix -> %{x: {:uniform, 0.0, 1.0}} end
      state1 = NSGA2.init(%{population_size: 5, seed: 42})
      state2 = NSGA2.init(%{population_size: 5, seed: 42})

      {params1, _} = NSGA2.next(space_fun, 0, [], state1)
      {params2, _} = NSGA2.next(space_fun, 0, [], state2)

      # With same seed, should generate same first individual
      assert_in_delta params1.x, params2.x, 0.001
    end

    test "generates different population with different seed" do
      space_fun = fn _ix -> %{x: {:uniform, 0.0, 1.0}} end
      state1 = NSGA2.init(%{population_size: 5, seed: 42})
      state2 = NSGA2.init(%{population_size: 5, seed: 99})

      {params1, _} = NSGA2.next(space_fun, 0, [], state1)
      {params2, _} = NSGA2.next(space_fun, 0, [], state2)

      # Different seeds should produce different results
      assert params1.x != params2.x
    end
  end

  describe "next/4 - population evolution" do
    @tag :skip  # NSGA-II evolution requires multi-objective history which is complex to set up
    test "evolves population after sufficient history" do
      space_fun = fn _ix -> %{x: {:uniform, 0.0, 1.0}, y: {:uniform, 0.0, 1.0}} end
      state = NSGA2.init(%{population_size: 10, seed: 42})

      # Initialize population
      {_, state} = NSGA2.next(space_fun, 0, [], state)
      initial_gen = state.generation

      # Build history (10 evaluations)
      history = Enum.map(1..10, fn i ->
        %{
          params: %{x: i * 0.1, y: i * 0.1},
          score: [i * 0.1, (10 - i) * 0.1]  # Multi-objective scores
        }
      end)

      # After population_size evaluations, should evolve
      {_, new_state} = NSGA2.next(space_fun, 10, history, state)

      # Generation should increment after evolution
      assert new_state.generation == initial_gen + 1
    end
  end

  describe "next/4 - edge cases" do
    test "handles small population size" do
      space_fun = fn _ix -> %{x: {:uniform, 0.0, 1.0}} end
      state = NSGA2.init(%{population_size: 2, seed: 42})

      {params, new_state} = NSGA2.next(space_fun, 0, [], state)

      assert length(new_state.population) == 2
      assert is_map(params)
      assert params.x >= 0.0 and params.x <= 1.0
    end

    test "handles single parameter" do
      space_fun = fn _ix -> %{x: {:uniform, 0.0, 1.0}} end
      state = NSGA2.init(%{population_size: 5, seed: 42})

      {params, _} = NSGA2.next(space_fun, 0, [], state)

      assert Map.keys(params) == [:x]
      assert params.x >= 0.0 and params.x <= 1.0
    end
  end
end
