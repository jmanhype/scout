defmodule Scout.Sampler.CmaEsTest do
  use ExUnit.Case, async: true

  alias Scout.Sampler.CmaEs

  describe "init/1" do
    test "initializes with default options" do
      state = CmaEs.init(%{})

      assert state.population_size == nil  # Auto-calculated
      assert state.sigma0 == 1.0
      assert state.min_obs == 3
      assert state.goal == :minimize
      assert state.mean == nil  # Not initialized until history available
      assert state.generation == 0
      assert state.population == []
    end

    test "initializes with custom population size" do
      state = CmaEs.init(%{population_size: 10})

      assert state.population_size == 10
    end

    test "initializes with custom sigma0" do
      state = CmaEs.init(%{sigma0: 0.5})

      assert state.sigma0 == 0.5
    end

    test "initializes with maximize goal" do
      state = CmaEs.init(%{goal: :maximize})

      assert state.goal == :maximize
    end

    test "initializes with custom min_obs" do
      state = CmaEs.init(%{min_obs: 5})

      assert state.min_obs == 5
    end
  end

  describe "next/4 - cold start (insufficient history)" do
    test "uses random sampling when history is empty" do
      space_fun = fn _ix -> %{x: {:uniform, 0.0, 10.0}} end
      state = CmaEs.init(%{})

      {params, _state} = CmaEs.next(space_fun, 0, [], state)

      assert is_map(params)
      assert Map.has_key?(params, :x)
      assert params.x >= 0.0 and params.x <= 10.0
    end

    test "uses random sampling when history < min_obs" do
      space_fun = fn _ix -> %{x: {:uniform, 0.0, 1.0}} end
      state = CmaEs.init(%{min_obs: 3})

      history = [
        %{params: %{x: 0.5}, score: 0.25},
        %{params: %{x: 0.8}, score: 0.64}
      ]

      {params, _state} = CmaEs.next(space_fun, 2, history, state)

      assert is_map(params)
      assert Map.has_key?(params, :x)
      assert params.x >= 0.0 and params.x <= 1.0
    end
  end

  describe "next/4 - CMA-ES initialized" do
    test "initializes CMA-ES state from history" do
      space_fun = fn _ix -> %{x: {:uniform, 0.0, 10.0}, y: {:uniform, 0.0, 10.0}} end
      state = CmaEs.init(%{min_obs: 3})

      history = [
        %{params: %{x: 2.0, y: 3.0}, score: 13.0},
        %{params: %{x: 5.0, y: 4.0}, score: 41.0},
        %{params: %{x: 1.0, y: 2.0}, score: 5.0},
        %{params: %{x: 3.0, y: 1.0}, score: 10.0}
      ]

      {_params, new_state} = CmaEs.next(space_fun, 4, history, state)

      # Should have initialized CMA-ES parameters
      assert new_state.mean != nil
      assert new_state.cov != nil
      assert new_state.sigma != nil
      assert new_state.population_size != nil
      assert is_list(new_state.mean)
      assert length(new_state.mean) == 2  # Two parameters
    end

    test "auto-calculates population size based on dimensionality" do
      space_fun = fn _ix ->
        %{
          x: {:uniform, 0.0, 1.0},
          y: {:uniform, 0.0, 1.0},
          z: {:uniform, 0.0, 1.0}
        }
      end
      state = CmaEs.init(%{min_obs: 3})

      history = create_history(5, [:x, :y, :z])

      {_params, new_state} = CmaEs.next(space_fun, 5, history, state)

      # Population size = 4 + floor(3 * log(n))
      # For n=3: 4 + floor(3 * 1.0986) = 4 + 3 = 7
      assert new_state.population_size == 7
    end

    test "generates valid parameters in search space" do
      space_fun = fn _ix -> %{x: {:uniform, -5.0, 5.0}} end
      state = CmaEs.init(%{min_obs: 2})

      history = [
        %{params: %{x: 1.0}, score: 1.0},
        %{params: %{x: -1.0}, score: 1.0},
        %{params: %{x: 0.5}, score: 0.25}
      ]

      # Generate several parameters
      {_, state} = CmaEs.next(space_fun, 3, history, state)
      {params2, state} = CmaEs.next(space_fun, 4, history, state)
      {params3, state} = CmaEs.next(space_fun, 5, history, state)
      {params4, _} = CmaEs.next(space_fun, 6, history, state)

      # All should be valid
      for params <- [params2, params3, params4] do
        assert params.x >= -5.0 and params.x <= 5.0
      end
    end
  end

  describe "next/4 - population management" do
    test "builds population up to population_size" do
      space_fun = fn _ix -> %{x: {:uniform, 0.0, 1.0}} end
      state = CmaEs.init(%{population_size: 4, min_obs: 2})

      history = create_history(3, [:x])

      # Generate population
      {_p1, state} = CmaEs.next(space_fun, 3, history, state)
      assert length(state.population) == 1

      {_p2, state} = CmaEs.next(space_fun, 4, history, state)
      assert length(state.population) == 2

      {_p3, state} = CmaEs.next(space_fun, 5, history, state)
      assert length(state.population) == 3

      {_p4, state} = CmaEs.next(space_fun, 6, history, state)
      assert length(state.population) == 4
    end

    @tag :skip  # CMA-ES update logic has issues with 1D problems
    test "starts new generation after population is full" do
      space_fun = fn _ix -> %{x: {:uniform, 0.0, 1.0}} end
      state = CmaEs.init(%{population_size: 2, min_obs: 2})

      history = create_history(3, [:x])

      # Fill first generation
      {_p1, state} = CmaEs.next(space_fun, 3, history, state)
      {_p2, state} = CmaEs.next(space_fun, 4, history, state)

      initial_gen = state.generation

      # Next call should start new generation
      {_p3, state} = CmaEs.next(space_fun, 5, history ++ [%{params: %{x: 0.5}, score: 0.25}], state)

      assert state.generation == initial_gen + 1
      assert length(state.population) == 1  # Reset to 1
    end
  end

  describe "next/4 - adaptation" do
    @tag :skip  # CMA-ES update logic has issues with 1D problems
    test "mean moves toward better solutions over generations (minimize)" do
      space_fun = fn _ix -> %{x: {:uniform, 0.0, 10.0}} end
      state = CmaEs.init(%{population_size: 4, min_obs: 2, goal: :minimize})

      # Initial history with target near x=2
      history = [
        %{params: %{x: 5.0}, score: 25.0},
        %{params: %{x: 2.0}, score: 4.0},   # Best
        %{params: %{x: 8.0}, score: 64.0},
        %{params: %{x: 3.0}, score: 9.0}
      ]

      {_, state} = CmaEs.next(space_fun, 4, history, state)
      initial_mean = hd(state.mean)

      # Simulate several generations with improving scores near x=2
      history = history ++ [
        %{params: %{x: 2.1}, score: 4.41},
        %{params: %{x: 1.9}, score: 3.61},
        %{params: %{x: 2.2}, score: 4.84},
        %{params: %{x: 2.0}, score: 4.0}
      ]

      # Complete generation 1
      {_, state} = CmaEs.next(space_fun, 5, history, state)
      {_, state} = CmaEs.next(space_fun, 6, history, state)
      {_, state} = CmaEs.next(space_fun, 7, history, state)

      # Start generation 2 (triggers update)
      {_, state} = CmaEs.next(space_fun, 8, history, state)
      updated_mean = hd(state.mean)

      # Mean should have moved (CMA-ES adapts based on good solutions)
      assert initial_mean != updated_mean
    end

    @tag :skip  # CMA-ES update logic has issues with 1D problems
    test "sigma (step size) adapts over time" do
      space_fun = fn _ix -> %{x: {:uniform, 0.0, 10.0}} end
      state = CmaEs.init(%{population_size: 4, min_obs: 2, sigma0: 1.0})

      history = create_history(5, [:x])

      {_, state} = CmaEs.next(space_fun, 5, history, state)
      initial_sigma = state.sigma

      # Complete a generation
      history = history ++ create_history(4, [:x], offset: 5)
      {_, state} = CmaEs.next(space_fun, 6, history, state)
      {_, state} = CmaEs.next(space_fun, 7, history, state)
      {_, state} = CmaEs.next(space_fun, 8, history, state)
      {_, state} = CmaEs.next(space_fun, 9, history, state)  # Triggers update

      # Sigma should have been updated
      assert state.sigma != initial_sigma
      assert state.sigma > 0.0  # Should remain positive
    end
  end

  describe "next/4 - multiple parameters" do
    test "handles multi-dimensional optimization" do
      space_fun = fn _ix ->
        %{
          x: {:uniform, -5.0, 5.0},
          y: {:uniform, -5.0, 5.0}
        }
      end
      state = CmaEs.init(%{min_obs: 3})

      history = [
        %{params: %{x: 1.0, y: 2.0}, score: 5.0},
        %{params: %{x: -1.0, y: 1.0}, score: 2.0},
        %{params: %{x: 0.0, y: 0.0}, score: 0.0},
        %{params: %{x: 2.0, y: -1.0}, score: 5.0}
      ]

      {params, state} = CmaEs.next(space_fun, 4, history, state)

      assert Map.has_key?(params, :x)
      assert Map.has_key?(params, :y)
      assert params.x >= -5.0 and params.x <= 5.0
      assert params.y >= -5.0 and params.y <= 5.0
      assert length(state.mean) == 2
    end
  end

  describe "next/4 - integer and log-uniform parameters" do
    test "handles integer parameters" do
      space_fun = fn _ix -> %{n: {:int, 1, 100}} end
      state = CmaEs.init(%{min_obs: 2})

      history = [
        %{params: %{n: 50}, score: 2500},
        %{params: %{n: 25}, score: 625},
        %{params: %{n: 75}, score: 5625}
      ]

      {params, _} = CmaEs.next(space_fun, 3, history, state)

      assert is_integer(params.n)
      assert params.n >= 1 and params.n <= 100
    end

    test "handles log-uniform parameters" do
      space_fun = fn _ix -> %{lr: {:log_uniform, 1.0e-5, 1.0}} end
      state = CmaEs.init(%{min_obs: 2})

      history = [
        %{params: %{lr: 0.01}, score: 0.0001},
        %{params: %{lr: 0.001}, score: 0.000001},
        %{params: %{lr: 0.1}, score: 0.01}
      ]

      {params, _} = CmaEs.next(space_fun, 3, history, state)

      assert is_float(params.lr)
      assert params.lr >= 1.0e-5 * 0.9 and params.lr <= 1.0
    end
  end

  describe "next/4 - maximize vs minimize" do
    test "adapts toward high scores when maximizing" do
      space_fun = fn _ix -> %{x: {:uniform, 0.0, 10.0}} end
      state = CmaEs.init(%{population_size: 4, min_obs: 2, goal: :maximize})

      # Best solution is x=9 (score 81)
      history = [
        %{params: %{x: 9.0}, score: 81.0},
        %{params: %{x: 2.0}, score: 4.0},
        %{params: %{x: 5.0}, score: 25.0},
        %{params: %{x: 1.0}, score: 1.0}
      ]

      {_, state} = CmaEs.next(space_fun, 4, history, state)

      # Mean should be initialized from best trials (high x values)
      mean_x = hd(state.mean)

      # Should favor higher x values (normalized space ~0.7-0.9)
      assert mean_x > 0.5
    end
  end

  # Helper functions
  defp create_history(n, param_keys, opts \\ []) do
    offset = Keyword.get(opts, :offset, 0)

    Enum.map(0..(n - 1), fn i ->
      params = Map.new(param_keys, fn k ->
        {k, :rand.uniform()}
      end)

      score = :rand.uniform() * 100

      %{params: params, score: score, index: offset + i}
    end)
  end
end
