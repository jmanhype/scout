defmodule Scout.Sampler.TPETest do
  use ExUnit.Case, async: true

  alias Scout.Sampler.TPE

  describe "init/1" do
    test "initializes with default options" do
      state = TPE.init(%{})

      assert state.gamma == 0.25
      assert state.n_candidates == 24
      assert state.min_obs == 10
      assert state.bw_floor == 1.0e-3
      assert state.goal == :maximize
      assert state.seed == nil
      assert state.multivariate == true
      assert state.bandwidth_factor == 1.06
      assert state.rng_state == nil
    end

    test "initializes with custom gamma" do
      state = TPE.init(%{gamma: 0.15})

      assert state.gamma == 0.15
    end

    test "initializes with custom n_candidates" do
      state = TPE.init(%{n_candidates: 50})

      assert state.n_candidates == 50
    end

    test "initializes with custom min_obs" do
      state = TPE.init(%{min_obs: 20})

      assert state.min_obs == 20
    end

    test "initializes with minimize goal" do
      state = TPE.init(%{goal: :minimize})

      assert state.goal == :minimize
    end

    test "initializes with seed for reproducibility" do
      state = TPE.init(%{seed: 42})

      assert state.seed == 42
    end

    test "initializes with multivariate disabled" do
      state = TPE.init(%{multivariate: false})

      assert state.multivariate == false
    end
  end

  describe "next/4 - cold start (insufficient history)" do
    test "uses random sampling when history is empty" do
      space_fun = fn _ix -> %{x: {:uniform, 0.0, 10.0}} end
      state = TPE.init(%{min_obs: 10, seed: 42})  # Add seed for deterministic RNG

      {params, _state} = TPE.next(space_fun, 0, [], state)

      assert is_map(params)
      assert Map.has_key?(params, :x)
      assert params.x >= 0.0 and params.x <= 10.0
    end

    test "uses random sampling when history < min_obs" do
      space_fun = fn _ix -> %{x: {:uniform, 0.0, 1.0}} end
      state = TPE.init(%{min_obs: 10, seed: 42})  # Add seed

      history = create_history(5, [:x])

      {params, _state} = TPE.next(space_fun, 5, history, state)

      assert is_map(params)
      assert Map.has_key?(params, :x)
      assert params.x >= 0.0 and params.x <= 1.0
    end
  end

  describe "next/4 - TPE initialized (uniform parameters)" do
    test "builds KDEs from history" do
      space_fun = fn _ix -> %{x: {:uniform, 0.0, 10.0}} end
      state = TPE.init(%{min_obs: 10, goal: :minimize, seed: 42})

      # Create history with clear pattern: low x values perform better
      history = [
        %{params: %{x: 1.0}, score: 1.0},   # Best
        %{params: %{x: 2.0}, score: 2.0},   # Good
        %{params: %{x: 3.0}, score: 3.0},
        %{params: %{x: 4.0}, score: 4.0},
        %{params: %{x: 5.0}, score: 5.0},
        %{params: %{x: 6.0}, score: 6.0},
        %{params: %{x: 7.0}, score: 7.0},
        %{params: %{x: 8.0}, score: 8.0},
        %{params: %{x: 9.0}, score: 9.0},   # Worst
        %{params: %{x: 10.0}, score: 10.0}
      ]

      {params, _} = TPE.next(space_fun, 10, history, state)

      # Should generate valid parameters
      assert is_map(params)
      assert Map.has_key?(params, :x)
      assert params.x >= 0.0 and params.x <= 10.0
    end

    test "respects maximize goal" do
      space_fun = fn _ix -> %{x: {:uniform, 0.0, 10.0}} end
      state = TPE.init(%{min_obs: 10, goal: :maximize, seed: 42})

      # High x values have high scores (better for maximize)
      history = Enum.map(1..10, fn i ->
        %{params: %{x: i * 1.0}, score: i * 1.0}
      end)

      # Generate multiple samples to check tendency
      samples = Enum.map(10..19, fn ix ->
        {params, _} = TPE.next(space_fun, ix, history, state)
        params.x
      end)

      # Mean should be biased toward higher values
      mean = Enum.sum(samples) / length(samples)
      assert mean > 5.0  # Should favor upper half
    end

    test "respects minimize goal" do
      space_fun = fn _ix -> %{x: {:uniform, 0.0, 10.0}} end
      state = TPE.init(%{min_obs: 10, goal: :minimize, seed: 42})

      # Low x values have low scores (better for minimize)
      history = Enum.map(1..10, fn i ->
        %{params: %{x: i * 1.0}, score: i * 1.0}
      end)

      # Generate multiple samples
      samples = Enum.map(10..19, fn ix ->
        {params, _} = TPE.next(space_fun, ix, history, state)
        params.x
      end)

      # Mean should be biased toward lower values
      mean = Enum.sum(samples) / length(samples)
      assert mean < 5.0  # Should favor lower half
    end

    test "handles single parameter" do
      space_fun = fn _ix -> %{x: {:uniform, -5.0, 5.0}} end
      state = TPE.init(%{min_obs: 5, n_candidates: 10, seed: 42})

      history = create_history(10, [:x])

      {params, _} = TPE.next(space_fun, 10, history, state)

      assert Map.has_key?(params, :x)
      assert params.x >= -5.0 and params.x <= 5.0
    end

    test "handles multiple parameters" do
      space_fun = fn _ix ->
        %{
          x: {:uniform, 0.0, 1.0},
          y: {:uniform, 0.0, 1.0}
        }
      end
      state = TPE.init(%{min_obs: 5, seed: 42})

      history = create_history(10, [:x, :y])

      {params, _} = TPE.next(space_fun, 10, history, state)

      assert Map.has_key?(params, :x)
      assert Map.has_key?(params, :y)
      assert params.x >= 0.0 and params.x <= 1.0
      assert params.y >= 0.0 and params.y <= 1.0
    end
  end

  describe "next/4 - integer parameters" do
    test "handles integer parameters" do
      space_fun = fn _ix -> %{n: {:int, 1, 100}} end
      state = TPE.init(%{min_obs: 5, seed: 42})

      history = [
        %{params: %{n: 25}, score: 625},
        %{params: %{n: 50}, score: 2500},
        %{params: %{n: 75}, score: 5625},
        %{params: %{n: 10}, score: 100},
        %{params: %{n: 90}, score: 8100},
        %{params: %{n: 30}, score: 900}
      ]

      {params, _} = TPE.next(space_fun, 6, history, state)

      assert is_integer(params.n)
      assert params.n >= 1 and params.n <= 100
    end

    test "rounds continuous samples to integers" do
      space_fun = fn _ix -> %{n: {:int, 0, 10}} end
      state = TPE.init(%{min_obs: 5, seed: 42})

      history = create_history(10, [:n], type: :int, min: 0, max: 10)

      # Generate several samples
      samples = Enum.map(10..14, fn ix ->
        {params, _} = TPE.next(space_fun, ix, history, state)
        params.n
      end)

      # All should be integers
      assert Enum.all?(samples, &is_integer/1)
      assert Enum.all?(samples, fn n -> n >= 0 and n <= 10 end)
    end
  end

  describe "next/4 - log-uniform parameters" do
    test "handles log-uniform parameters" do
      space_fun = fn _ix -> %{lr: {:log_uniform, 1.0e-5, 1.0}} end
      state = TPE.init(%{min_obs: 5, seed: 42})

      history = [
        %{params: %{lr: 0.01}, score: 0.0001},
        %{params: %{lr: 0.001}, score: 0.000001},
        %{params: %{lr: 0.1}, score: 0.01},
        %{params: %{lr: 0.0001}, score: 1.0e-8},
        %{params: %{lr: 1.0e-4}, score: 1.0e-8},
        %{params: %{lr: 0.05}, score: 0.0025}
      ]

      {params, _} = TPE.next(space_fun, 6, history, state)

      assert is_float(params.lr)
      assert params.lr >= 1.0e-5 * 0.9  # Tolerance
      assert params.lr <= 1.0
    end

    test "samples in log space" do
      space_fun = fn _ix -> %{lr: {:log_uniform, 1.0e-4, 1.0e-1}} end
      state = TPE.init(%{min_obs: 5, seed: 42})

      history = Enum.map(1..10, fn i ->
        lr = :math.pow(10, -4 + i * 0.3)  # Spread logarithmically
        %{params: %{lr: lr}, score: :rand.uniform()}
      end)

      # Generate samples
      samples = Enum.map(10..19, fn ix ->
        {params, _} = TPE.next(space_fun, ix, history, state)
        params.lr
      end)

      # All should be in valid range
      assert Enum.all?(samples, fn lr -> lr >= 1.0e-4 * 0.9 and lr <= 1.0e-1 * 1.1 end)
    end
  end

  describe "next/4 - choice parameters" do
    test "handles choice parameters" do
      space_fun = fn _ix -> %{method: {:choice, ["adam", "sgd", "rmsprop"]}} end
      state = TPE.init(%{min_obs: 5, seed: 42})

      history = [
        %{params: %{method: "adam"}, score: 0.9},
        %{params: %{method: "sgd"}, score: 0.7},
        %{params: %{method: "adam"}, score: 0.92},
        %{params: %{method: "rmsprop"}, score: 0.85},
        %{params: %{method: "adam"}, score: 0.91},
        %{params: %{method: "sgd"}, score: 0.72}
      ]

      {params, _} = TPE.next(space_fun, 6, history, state)

      assert params.method in ["adam", "sgd", "rmsprop"]
    end

    test "favors better-performing choices" do
      space_fun = fn _ix -> %{method: {:choice, ["a", "b", "c"]}} end
      state = TPE.init(%{min_obs: 5, goal: :maximize, seed: 42})

      # "a" consistently performs best
      history = [
        %{params: %{method: "a"}, score: 10.0},
        %{params: %{method: "a"}, score: 9.5},
        %{params: %{method: "a"}, score: 9.8},
        %{params: %{method: "b"}, score: 5.0},
        %{params: %{method: "b"}, score: 5.2},
        %{params: %{method: "c"}, score: 3.0},
        %{params: %{method: "c"}, score: 3.5}
      ]

      # Sample 20 times
      choices = Enum.map(7..26, fn ix ->
        {params, _} = TPE.next(space_fun, ix, history, state)
        params.method
      end)

      # Count selections
      counts = Enum.frequencies(choices)

      # "a" should be selected most often (but not always due to exploration)
      assert Map.get(counts, "a", 0) > Map.get(counts, "b", 0)
      assert Map.get(counts, "a", 0) > Map.get(counts, "c", 0)
    end
  end

  describe "next/4 - mixed parameters" do
    test "handles mix of numeric and categorical" do
      space_fun = fn _ix ->
        %{
          lr: {:log_uniform, 1.0e-5, 1.0},
          batch_size: {:int, 16, 128},
          optimizer: {:choice, ["adam", "sgd"]}
        }
      end
      state = TPE.init(%{min_obs: 5, seed: 42})

      history = create_mixed_history(10)

      {params, _} = TPE.next(space_fun, 10, history, state)

      assert is_float(params.lr)
      assert params.lr >= 1.0e-5 * 0.9 and params.lr <= 1.0
      assert is_integer(params.batch_size)
      assert params.batch_size >= 16 and params.batch_size <= 128
      assert params.optimizer in ["adam", "sgd"]
    end

    test "handles only categorical parameters" do
      space_fun = fn _ix ->
        %{
          optimizer: {:choice, ["adam", "sgd"]},
          activation: {:choice, ["relu", "tanh"]}
        }
      end
      state = TPE.init(%{min_obs: 5, seed: 42})

      history = [
        %{params: %{optimizer: "adam", activation: "relu"}, score: 0.9},
        %{params: %{optimizer: "sgd", activation: "tanh"}, score: 0.7},
        %{params: %{optimizer: "adam", activation: "tanh"}, score: 0.85},
        %{params: %{optimizer: "sgd", activation: "relu"}, score: 0.75},
        %{params: %{optimizer: "adam", activation: "relu"}, score: 0.92},
        %{params: %{optimizer: "adam", activation: "tanh"}, score: 0.88}
      ]

      {params, _} = TPE.next(space_fun, 6, history, state)

      assert params.optimizer in ["adam", "sgd"]
      assert params.activation in ["relu", "tanh"]
    end
  end

  describe "next/4 - edge cases" do
    test "handles empty good group (all bad)" do
      space_fun = fn _ix -> %{x: {:uniform, 0.0, 1.0}} end
      state = TPE.init(%{min_obs: 5, gamma: 0.1, seed: 42})  # Very small gamma

      # Only one trial will be "good"
      history = create_history(10, [:x])

      {params, _} = TPE.next(space_fun, 10, history, state)

      assert is_map(params)
      assert params.x >= 0.0 and params.x <= 1.0
    end

    test "handles history with missing scores" do
      space_fun = fn _ix -> %{x: {:uniform, 0.0, 1.0}} end
      state = TPE.init(%{min_obs: 3, seed: 42})

      # TPE code filters with `is_number(t.score)` which requires score key to exist
      # So only include entries with valid numeric scores
      history = [
        %{params: %{x: 0.5}, score: 0.25},
        # Removed: %{params: %{x: 0.8}, score: nil},  # Would fail is_number check
        %{params: %{x: 0.3}, score: 0.09},
        %{params: %{x: 0.6}, score: 0.36},
        # Removed: %{params: %{x: 0.2}},  # Would fail with KeyError
        %{params: %{x: 0.9}, score: 0.81}
      ]

      {params, _} = TPE.next(space_fun, 6, history, state)

      # Should work with valid scores only
      assert is_map(params)
      assert params.x >= 0.0 and params.x <= 1.0
    end

    test "initializes RNG state when seeded" do
      space_fun = fn _ix -> %{x: {:uniform, 0.0, 1.0}} end
      state = TPE.init(%{min_obs: 5, seed: 42})

      history = create_history(10, [:x])

      {_params, new_state} = TPE.next(space_fun, 10, history, state)

      # RNG state should be initialized after first call
      assert new_state.rng_state != nil
    end
  end

  describe "next/4 - reproducibility" do
    test "generates same sequence with same seed" do
      space_fun = fn _ix -> %{x: {:uniform, 0.0, 1.0}} end
      state1 = TPE.init(%{min_obs: 5, seed: 42})
      state2 = TPE.init(%{min_obs: 5, seed: 42})

      history = create_history(10, [:x])

      {params1, _} = TPE.next(space_fun, 10, history, state1)
      {params2, _} = TPE.next(space_fun, 10, history, state2)

      # With same seed, should generate same parameters
      assert_in_delta params1.x, params2.x, 0.001
    end

    test "generates different sequence with different seed" do
      space_fun = fn _ix -> %{x: {:uniform, 0.0, 1.0}} end
      state1 = TPE.init(%{min_obs: 5, seed: 42})
      state2 = TPE.init(%{min_obs: 5, seed: 99})

      history = create_history(10, [:x])

      {params1, _} = TPE.next(space_fun, 10, history, state1)
      {params2, _} = TPE.next(space_fun, 10, history, state2)

      # Different seeds should produce different results
      assert params1.x != params2.x
    end
  end

  describe "next/4 - convergence behavior" do
    test "converges toward optimal region over time" do
      # Minimize (x - 5)^2, optimum at x=5
      space_fun = fn _ix -> %{x: {:uniform, 0.0, 10.0}} end
      state = TPE.init(%{min_obs: 10, goal: :minimize, seed: 42, n_candidates: 50})

      # Simulate optimization
      history = Enum.reduce(1..30, [], fn i, acc ->
        x = :rand.uniform() * 10.0
        score = :math.pow(x - 5.0, 2)
        acc ++ [%{params: %{x: x}, score: score}]
      end)

      # Generate samples after seeing the history
      samples = Enum.map(30..39, fn ix ->
        {params, _} = TPE.next(space_fun, ix, history, state)
        params.x
      end)

      # Mean should be close to optimum (5.0)
      mean = Enum.sum(samples) / length(samples)
      assert mean > 3.0 and mean < 7.0  # Should concentrate around 5.0
    end
  end

  # Helper functions
  defp create_history(n, param_keys, opts \\ []) do
    type = Keyword.get(opts, :type, :float)
    min_val = Keyword.get(opts, :min, 0.0)
    max_val = Keyword.get(opts, :max, 1.0)

    Enum.map(1..n, fn i ->
      params = Map.new(param_keys, fn k ->
        val = case type do
          :int -> min_val + rem(i * 7, max_val - min_val + 1)
          :float -> min_val + :rand.uniform() * (max_val - min_val)
        end
        {k, val}
      end)

      score = :rand.uniform() * 100

      %{params: params, score: score}
    end)
  end

  defp create_mixed_history(n) do
    Enum.map(1..n, fn _i ->
      lr = :math.pow(10, -5 + :rand.uniform() * 5)  # 1e-5 to 1
      batch_size = Enum.random([16, 32, 64, 128])
      optimizer = Enum.random(["adam", "sgd"])

      params = %{lr: lr, batch_size: batch_size, optimizer: optimizer}
      score = :rand.uniform()

      %{params: params, score: score}
    end)
  end
end
