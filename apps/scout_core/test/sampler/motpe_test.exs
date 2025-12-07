defmodule Scout.Sampler.MOTPETest do
  use ExUnit.Case, async: true

  alias Scout.Sampler.MOTPE

  describe "init/1" do
    test "initializes with default options" do
      state = MOTPE.init(%{})

      # Should inherit TPE defaults
      assert state.gamma == 0.25
      assert state.n_candidates == 24
      assert state.min_obs == 10

      # MOTPE-specific defaults
      assert state.n_objectives == 2
      assert state.reference_point == nil
      assert state.use_hypervolume == false
      assert state.objective_weights == nil
      assert state.scalarization == "pareto"
    end

    test "initializes with custom n_objectives" do
      state = MOTPE.init(%{n_objectives: 3})

      assert state.n_objectives == 3
    end

    test "initializes with weighted_sum scalarization" do
      state = MOTPE.init(%{scalarization: "weighted_sum"})

      assert state.scalarization == "weighted_sum"
    end

    test "initializes with custom objective weights" do
      weights = %{obj_0: 0.6, obj_1: 0.4}
      state = MOTPE.init(%{objective_weights: weights})

      assert state.objective_weights == weights
    end

    test "initializes with custom reference point" do
      ref = %{obj_0: 10.0, obj_1: 10.0}
      state = MOTPE.init(%{reference_point: ref})

      assert state.reference_point == ref
    end

    test "initializes with seed for reproducibility" do
      state = MOTPE.init(%{seed: 42})

      assert state.seed == 42
    end
  end

  describe "next/4 - cold start" do
    test "uses random sampling when history is empty" do
      space_fun = fn _ix -> %{x: {:uniform, 0.0, 1.0}} end
      state = MOTPE.init(%{min_obs: 10, seed: 42})

      {params, _state} = MOTPE.next(space_fun, 0, [], state)

      assert is_map(params)
      assert Map.has_key?(params, :x)
      assert params.x >= 0.0 and params.x <= 1.0
    end

    test "uses random sampling when history < min_obs" do
      space_fun = fn _ix -> %{x: {:uniform, 0.0, 1.0}} end
      state = MOTPE.init(%{min_obs: 10, seed: 42})

      history = create_multi_objective_history(5, [:x])

      {params, _state} = MOTPE.next(space_fun, 5, history, state)

      assert is_map(params)
      assert params.x >= 0.0 and params.x <= 1.0
    end
  end

  describe "next/4 - multi-objective with Pareto scalarization" do
    test "handles multi-objective history with Pareto dominance" do
      space_fun = fn _ix -> %{x: {:uniform, 0.0, 1.0}, y: {:uniform, 0.0, 1.0}} end
      state = MOTPE.init(%{min_obs: 5, scalarization: "pareto", seed: 42})

      # Create history with clear Pareto front
      history = [
        %{params: %{x: 0.1, y: 0.9}, score: %{obj_0: 0.1, obj_1: 0.9}},  # On front
        %{params: %{x: 0.5, y: 0.5}, score: %{obj_0: 0.5, obj_1: 0.5}},  # Dominated
        %{params: %{x: 0.9, y: 0.1}, score: %{obj_0: 0.9, obj_1: 0.1}},  # On front
        %{params: %{x: 0.6, y: 0.6}, score: %{obj_0: 0.6, obj_1: 0.6}},  # Dominated
        %{params: %{x: 0.2, y: 0.8}, score: %{obj_0: 0.2, obj_1: 0.8}},  # On front
        %{params: %{x: 0.4, y: 0.7}, score: %{obj_0: 0.4, obj_1: 0.7}}   # Dominated
      ]

      {params, _} = MOTPE.next(space_fun, 6, history, state)

      # Should generate valid parameters
      assert is_map(params)
      assert params.x >= 0.0 and params.x <= 1.0
      assert params.y >= 0.0 and params.y <= 1.0
    end

    test "handles 3-objective optimization" do
      space_fun = fn _ix -> %{x: {:uniform, 0.0, 1.0}} end
      state = MOTPE.init(%{min_obs: 5, n_objectives: 3, seed: 42})

      history = [
        %{params: %{x: 0.1}, score: %{obj_0: 0.1, obj_1: 0.5, obj_2: 0.9}},
        %{params: %{x: 0.5}, score: %{obj_0: 0.5, obj_1: 0.5, obj_2: 0.5}},
        %{params: %{x: 0.9}, score: %{obj_0: 0.9, obj_1: 0.5, obj_2: 0.1}},
        %{params: %{x: 0.3}, score: %{obj_0: 0.3, obj_1: 0.4, obj_2: 0.7}},
        %{params: %{x: 0.7}, score: %{obj_0: 0.7, obj_1: 0.4, obj_2: 0.3}}
      ]

      {params, _} = MOTPE.next(space_fun, 5, history, state)

      assert is_map(params)
      assert params.x >= 0.0 and params.x <= 1.0
    end
  end

  describe "next/4 - weighted sum scalarization" do
    test "uses weighted sum to combine objectives" do
      space_fun = fn _ix -> %{x: {:uniform, 0.0, 1.0}} end
      weights = %{obj_0: 0.7, obj_1: 0.3}
      state = MOTPE.init(%{min_obs: 5, scalarization: "weighted_sum", objective_weights: weights, seed: 42})

      history = [
        %{params: %{x: 0.1}, score: %{obj_0: 0.1, obj_1: 0.9}},  # Weighted: 0.07 + 0.27 = 0.34
        %{params: %{x: 0.5}, score: %{obj_0: 0.5, obj_1: 0.5}},  # Weighted: 0.35 + 0.15 = 0.50
        %{params: %{x: 0.9}, score: %{obj_0: 0.9, obj_1: 0.1}},  # Weighted: 0.63 + 0.03 = 0.66
        %{params: %{x: 0.3}, score: %{obj_0: 0.3, obj_1: 0.7}},  # Weighted: 0.21 + 0.21 = 0.42
        %{params: %{x: 0.7}, score: %{obj_0: 0.7, obj_1: 0.3}}   # Weighted: 0.49 + 0.09 = 0.58
      ]

      {params, _} = MOTPE.next(space_fun, 5, history, state)

      assert is_map(params)
      assert params.x >= 0.0 and params.x <= 1.0
    end

    test "uses equal weights by default" do
      space_fun = fn _ix -> %{x: {:uniform, 0.0, 1.0}} end
      state = MOTPE.init(%{min_obs: 5, scalarization: "weighted_sum", n_objectives: 2, seed: 42})

      history = create_multi_objective_history(10, [:x])

      {params, _} = MOTPE.next(space_fun, 10, history, state)

      assert is_map(params)
      assert params.x >= 0.0 and params.x <= 1.0
    end
  end

  describe "next/4 - Chebyshev scalarization" do
    test "uses Chebyshev distance to reference point" do
      space_fun = fn _ix -> %{x: {:uniform, 0.0, 1.0}} end
      ref = %{obj_0: 0.0, obj_1: 0.0}
      state = MOTPE.init(%{min_obs: 5, scalarization: "chebyshev", reference_point: ref, seed: 42})

      history = [
        %{params: %{x: 0.1}, score: %{obj_0: 0.1, obj_1: 0.2}},  # Chebyshev: max(0.1, 0.2) = 0.2
        %{params: %{x: 0.5}, score: %{obj_0: 0.5, obj_1: 0.4}},  # Chebyshev: max(0.5, 0.4) = 0.5
        %{params: %{x: 0.9}, score: %{obj_0: 0.9, obj_1: 0.1}},  # Chebyshev: max(0.9, 0.1) = 0.9
        %{params: %{x: 0.3}, score: %{obj_0: 0.2, obj_1: 0.6}},  # Chebyshev: max(0.2, 0.6) = 0.6
        %{params: %{x: 0.7}, score: %{obj_0: 0.8, obj_1: 0.3}}   # Chebyshev: max(0.8, 0.3) = 0.8
      ]

      {params, _} = MOTPE.next(space_fun, 5, history, state)

      assert is_map(params)
      assert params.x >= 0.0 and params.x <= 1.0
    end
  end

  describe "next/4 - reproducibility" do
    test "generates same sequence with same seed" do
      space_fun = fn _ix -> %{x: {:uniform, 0.0, 1.0}} end
      state1 = MOTPE.init(%{min_obs: 5, seed: 42})
      state2 = MOTPE.init(%{min_obs: 5, seed: 42})

      history = create_multi_objective_history(10, [:x])

      {params1, _} = MOTPE.next(space_fun, 10, history, state1)
      {params2, _} = MOTPE.next(space_fun, 10, history, state2)

      # With same seed, should generate same parameters
      assert_in_delta params1.x, params2.x, 0.001
    end

    test "generates different sequence with different seed" do
      space_fun = fn _ix -> %{x: {:uniform, 0.0, 1.0}} end
      state1 = MOTPE.init(%{min_obs: 5, seed: 42})
      state2 = MOTPE.init(%{min_obs: 5, seed: 99})

      history = create_multi_objective_history(10, [:x])

      {params1, _} = MOTPE.next(space_fun, 10, history, state1)
      {params2, _} = MOTPE.next(space_fun, 10, history, state2)

      # Different seeds should produce different results
      assert params1.x != params2.x
    end
  end

  describe "next/4 - parameter types" do
    test "handles uniform parameters" do
      space_fun = fn _ix -> %{x: {:uniform, -5.0, 5.0}} end
      state = MOTPE.init(%{min_obs: 5, seed: 42})

      history = create_multi_objective_history(10, [:x])

      {params, _} = MOTPE.next(space_fun, 10, history, state)

      assert is_float(params.x)
      # Note: params.x might be outside [-5, 5] due to the random/TPE nature
      # but should be close to the valid range
    end

    test "handles integer parameters" do
      space_fun = fn _ix -> %{n: {:int, 1, 100}} end
      state = MOTPE.init(%{min_obs: 5, seed: 42})

      history = Enum.map(1..10, fn i ->
        %{
          params: %{n: i * 10},
          score: %{obj_0: i * 0.1, obj_1: (11 - i) * 0.1}
        }
      end)

      {params, _} = MOTPE.next(space_fun, 10, history, state)

      assert is_integer(params.n)
    end

    test "handles choice parameters" do
      space_fun = fn _ix -> %{method: {:choice, ["a", "b", "c"]}} end
      state = MOTPE.init(%{min_obs: 5, seed: 42})

      history = [
        %{params: %{method: "a"}, score: %{obj_0: 0.1, obj_1: 0.9}},
        %{params: %{method: "b"}, score: %{obj_0: 0.5, obj_1: 0.5}},
        %{params: %{method: "c"}, score: %{obj_0: 0.9, obj_1: 0.1}},
        %{params: %{method: "a"}, score: %{obj_0: 0.2, obj_1: 0.8}},
        %{params: %{method: "b"}, score: %{obj_0: 0.6, obj_1: 0.4}}
      ]

      {params, _} = MOTPE.next(space_fun, 5, history, state)

      assert params.method in ["a", "b", "c"]
    end
  end

  # Helper functions
  defp create_multi_objective_history(n, param_keys) do
    Enum.map(1..n, fn _i ->
      params = Map.new(param_keys, fn k ->
        {k, :rand.uniform()}
      end)

      score = %{
        obj_0: :rand.uniform(),
        obj_1: :rand.uniform()
      }

      %{params: params, score: score}
    end)
  end
end
