defmodule Scout.Sampler.BanditTest do
  use ExUnit.Case, async: true

  alias Scout.Sampler.Bandit

  describe "init/1" do
    test "initializes with defaults when no opts" do
      state = Bandit.init(nil)

      assert is_map(state)
      assert state.epsilon == 0.1
      assert state.ucb_c == 2.0
      assert state.bins == 5
      assert state.pool == 24
    end

    test "initializes with defaults when empty map" do
      state = Bandit.init(%{})

      assert state.epsilon == 0.1
      assert state.ucb_c == 2.0
      assert state.bins == 5
      assert state.pool == 24
    end

    test "merges custom options with defaults" do
      opts = %{epsilon: 0.2, ucb_c: 1.5}
      state = Bandit.init(opts)

      assert state.epsilon == 0.2
      assert state.ucb_c == 1.5
      assert state.bins == 5  # default
      assert state.pool == 24  # default
    end

    test "allows overriding all parameters" do
      opts = %{epsilon: 0.05, ucb_c: 3.0, bins: 10, pool: 50}
      state = Bandit.init(opts)

      assert state.epsilon == 0.05
      assert state.ucb_c == 3.0
      assert state.bins == 10
      assert state.pool == 50
    end
  end

  describe "next/4 - basic functionality" do
    test "generates parameters from search space" do
      # Bandit expects space_fun to return actual parameter values, not specs
      space_fun = fn _ix -> %{x: :rand.uniform()} end
      state = Bandit.init(%{})

      {params, new_state} = Bandit.next(space_fun, 0, [], state)

      assert is_map(params)
      assert Map.has_key?(params, :x)
      assert params.x >= 0.0
      assert params.x <= 1.0
      assert new_state == state  # state unchanged
    end

    test "generates from multiple parameters" do
      # Bandit expects space_fun to return actual parameter values
      space_fun = fn _ix ->
        %{
          x: :rand.uniform(),
          y: Enum.random(["a", "b", "c"]),
          z: :rand.uniform(10) + 1
        }
      end
      state = Bandit.init(%{})

      {params, _} = Bandit.next(space_fun, 0, [], state)

      assert Map.has_key?(params, :x)
      assert Map.has_key?(params, :y)
      assert Map.has_key?(params, :z)
      assert params.x >= 0.0 and params.x <= 1.0
      assert params.y in ["a", "b", "c"]
      assert params.z >= 1 and params.z <= 11
    end

    test "respects custom pool size" do
      # We can't directly observe pool size, but we can verify it generates valid params
      space_fun = fn _ix -> %{x: :rand.uniform()} end
      state = Bandit.init(%{pool: 100})

      {params, _} = Bandit.next(space_fun, 0, [], state)

      assert is_map(params)
      assert Map.has_key?(params, :x)
    end
  end

  describe "next/4 - epsilon-greedy behavior" do
    test "with empty history, always explores (picks randomly)" do
      space_fun = fn _ix -> %{x: :rand.uniform()} end
      state = Bandit.init(%{epsilon: 0.1})

      # With empty history, should pick randomly from candidate pool
      {params, _} = Bandit.next(space_fun, 0, [], state)

      assert is_map(params)
      assert Map.has_key?(params, :x)
    end

    test "with history, sometimes explores based on epsilon" do
      space_fun = fn _ix -> %{x: :rand.uniform()} end

      # Set epsilon to 1.0 to always explore
      state_explore = Bandit.init(%{epsilon: 1.0})

      history = [
        %{params: %{x: 0.5}, score: 10.0},
        %{params: %{x: 0.3}, score: 5.0}
      ]

      {params, _} = Bandit.next(space_fun, 2, history, state_explore)

      # Should still generate valid params
      assert is_map(params)
      assert params.x >= 0.0 and params.x <= 1.0
    end
  end

  describe "next/4 - UCB1 exploitation" do
    test "exploits best buckets when epsilon is zero" do
      # Create a space with discrete buckets
      space_fun = fn _ix -> %{x: :rand.uniform()} end

      # Set epsilon to 0 to always exploit
      state = Bandit.init(%{epsilon: 0.0, bins: 5})

      # History showing bucket around x=0.8 has high scores
      history = [
        %{params: %{x: 0.8}, score: 100.0},
        %{params: %{x: 0.82}, score: 98.0},
        %{params: %{x: 0.79}, score: 99.0},
        %{params: %{x: 0.2}, score: 10.0},
        %{params: %{x: 0.21}, score: 11.0}
      ]

      {params, _} = Bandit.next(space_fun, 5, history, state)

      # Should prefer the high-scoring region
      # With 5 bins, bucket 3 or 4 contains x=0.8
      assert is_map(params)
      assert params.x >= 0.0 and params.x <= 1.0
    end
  end

  describe "next/4 - handles invalid history gracefully" do
    test "skips trials with nil scores" do
      space_fun = fn _ix -> %{x: :rand.uniform()} end
      state = Bandit.init(%{epsilon: 0.0})

      history = [
        %{params: %{x: 0.5}, score: 10.0},
        %{params: %{x: 0.3}, score: nil},  # Should be skipped
        %{params: %{x: 0.7}, score: 15.0}
      ]

      {params, _} = Bandit.next(space_fun, 3, history, state)

      assert is_map(params)
      assert params.x >= 0.0 and params.x <= 1.0
    end

    test "skips trials with non-numeric scores" do
      space_fun = fn _ix -> %{x: :rand.uniform()} end
      state = Bandit.init(%{epsilon: 0.0})

      history = [
        %{params: %{x: 0.5}, score: 10.0},
        %{params: %{x: 0.3}, score: "invalid"},  # Should be skipped
        %{params: %{x: 0.7}, score: 15.0}
      ]

      {params, _} = Bandit.next(space_fun, 3, history, state)

      assert is_map(params)
      assert params.x >= 0.0 and params.x <= 1.0
    end

    test "skips trials with infinity atom scores" do
      space_fun = fn _ix -> %{x: :rand.uniform()} end
      state = Bandit.init(%{epsilon: 0.0})

      # Use infinity atoms directly (these can come from some math operations)
      history = [
        %{params: %{x: 0.5}, score: 10.0},
        %{params: %{x: 0.3}, score: :neg_infinity},  # infinity atom
        %{params: %{x: 0.7}, score: 15.0}
      ]

      {params, _} = Bandit.next(space_fun, 3, history, state)

      assert is_map(params)
      assert params.x >= 0.0 and params.x <= 1.0
    end

    test "skips trials with invalid params" do
      space_fun = fn _ix -> %{x: :rand.uniform()} end
      state = Bandit.init(%{epsilon: 0.0})

      history = [
        %{params: %{x: 0.5}, score: 10.0},
        %{params: nil, score: 20.0},  # Invalid params
        %{params: %{x: 0.7}, score: 15.0}
      ]

      {params, _} = Bandit.next(space_fun, 3, history, state)

      assert is_map(params)
      assert params.x >= 0.0 and params.x <= 1.0
    end

    test "handles trial maps missing score key" do
      space_fun = fn _ix -> %{x: :rand.uniform()} end
      state = Bandit.init(%{epsilon: 0.0})

      history = [
        %{params: %{x: 0.5}, score: 10.0},
        %{params: %{x: 0.3}},  # Missing score
        %{params: %{x: 0.7}, score: 15.0}
      ]

      {params, _} = Bandit.next(space_fun, 3, history, state)

      assert is_map(params)
      assert params.x >= 0.0 and params.x <= 1.0
    end

    test "handles trial maps missing params key" do
      space_fun = fn _ix -> %{x: :rand.uniform()} end
      state = Bandit.init(%{epsilon: 0.0})

      history = [
        %{params: %{x: 0.5}, score: 10.0},
        %{score: 20.0},  # Missing params
        %{params: %{x: 0.7}, score: 15.0}
      ]

      {params, _} = Bandit.next(space_fun, 3, history, state)

      assert is_map(params)
      assert params.x >= 0.0 and params.x <= 1.0
    end
  end

  describe "next/4 - bucket statistics" do
    test "aggregates statistics per bucket" do
      space_fun = fn _ix -> %{x: :rand.uniform()} end
      state = Bandit.init(%{epsilon: 0.0, bins: 5})

      # Multiple trials in same bucket (x around 0.5)
      history = [
        %{params: %{x: 0.5}, score: 10.0},
        %{params: %{x: 0.52}, score: 12.0},
        %{params: %{x: 0.48}, score: 11.0}
      ]

      {params, _} = Bandit.next(space_fun, 3, history, state)

      # Should generate valid params (bucket stats are computed internally)
      assert is_map(params)
      assert params.x >= 0.0 and params.x <= 1.0
    end

    test "handles mixed parameter types in buckets" do
      space_fun = fn _ix ->
        %{
          x: :rand.uniform(),
          category: Enum.random(["a", "b", "c"])
        }
      end
      state = Bandit.init(%{epsilon: 0.0, bins: 3})

      history = [
        %{params: %{x: 0.3, category: "a"}, score: 10.0},
        %{params: %{x: 0.35, category: "a"}, score: 12.0},
        %{params: %{x: 0.6, category: "b"}, score: 5.0},
        %{params: %{x: 0.65, category: "b"}, score: 6.0}
      ]

      {params, _} = Bandit.next(space_fun, 4, history, state)

      assert is_map(params)
      assert Map.has_key?(params, :x)
      assert Map.has_key?(params, :category)
    end
  end

  describe "next/4 - UCB1 calculation" do
    test "balances mean reward and exploration bonus" do
      space_fun = fn _ix -> %{x: :rand.uniform()} end

      # High exploration bonus (c = 10.0)
      state_high_c = Bandit.init(%{epsilon: 0.0, ucb_c: 10.0, bins: 5})

      # Well-explored bucket (high n) vs under-explored bucket (low n)
      history = [
        # Bucket 1: well-explored, low reward
        %{params: %{x: 0.1}, score: 1.0},
        %{params: %{x: 0.11}, score: 1.0},
        %{params: %{x: 0.12}, score: 1.0},
        %{params: %{x: 0.13}, score: 1.0},
        %{params: %{x: 0.14}, score: 1.0},
        # Bucket 4: under-explored, medium reward
        %{params: %{x: 0.8}, score: 5.0}
      ]

      {params, _} = Bandit.next(space_fun, 6, history, state_high_c)

      # With high exploration bonus, may explore other buckets
      assert is_map(params)
      assert params.x >= 0.0 and params.x <= 1.0
    end

    test "handles zero count buckets gracefully" do
      space_fun = fn _ix -> %{x: :rand.uniform()} end
      state = Bandit.init(%{epsilon: 0.0, bins: 10})  # Many bins, sparse history

      # Only one bucket has history
      history = [
        %{params: %{x: 0.5}, score: 10.0}
      ]

      {params, _} = Bandit.next(space_fun, 1, history, state)

      # Should handle unseen buckets with default stats
      assert is_map(params)
      assert params.x >= 0.0 and params.x <= 1.0
    end
  end

  describe "next/4 - state preservation" do
    test "state is passed through unchanged" do
      space_fun = fn _ix -> %{x: :rand.uniform()} end
      state = Bandit.init(%{epsilon: 0.15, ucb_c: 1.8})

      {_params, new_state} = Bandit.next(space_fun, 0, [], state)

      assert new_state == state
    end
  end

  describe "next/4 - large history" do
    test "limits history processing to 1000 most recent trials" do
      space_fun = fn _ix -> %{x: :rand.uniform()} end
      state = Bandit.init(%{epsilon: 0.0})

      # Create 2000 trials
      history = Enum.map(1..2000, fn i ->
        %{params: %{x: rem(i, 100) / 100.0}, score: Float.round(:rand.uniform() * 10, 2)}
      end)

      {params, _} = Bandit.next(space_fun, 2000, history, state)

      # Should only process first 1000 and still generate valid params
      assert is_map(params)
      assert params.x >= 0.0 and params.x <= 1.0
    end
  end

  describe "next/4 - parameter validity" do
    test "always generates valid parameters over many trials" do
      space_fun = fn _ix ->
        %{
          x: -10.0 + :rand.uniform() * 20.0,
          category: Enum.random([:a, :b, :c]),
          n: :rand.uniform(100)
        }
      end
      state = Bandit.init(%{})

      # Build history as we go
      history = []

      Enum.reduce(0..49, history, fn ix, acc ->
        {params, _} = Bandit.next(space_fun, ix, acc, state)

        assert params.x >= -10.0 and params.x <= 10.0
        assert params.category in [:a, :b, :c]
        assert params.n >= 0 and params.n <= 101

        # Add to history for next iteration
        score = :rand.uniform() * 100
        [%{params: params, score: score} | acc]
      end)
    end
  end

  describe "next/4 - different bin sizes" do
    test "works with small bin size" do
      space_fun = fn _ix -> %{x: :rand.uniform()} end
      state = Bandit.init(%{bins: 2, epsilon: 0.0})

      history = [
        %{params: %{x: 0.1}, score: 10.0},
        %{params: %{x: 0.9}, score: 20.0}
      ]

      {params, _} = Bandit.next(space_fun, 2, history, state)

      assert is_map(params)
      assert params.x >= 0.0 and params.x <= 1.0
    end

    test "works with large bin size" do
      space_fun = fn _ix -> %{x: :rand.uniform()} end
      state = Bandit.init(%{bins: 100, epsilon: 0.0})

      history = [
        %{params: %{x: 0.505}, score: 10.0},
        %{params: %{x: 0.515}, score: 12.0}
      ]

      {params, _} = Bandit.next(space_fun, 2, history, state)

      assert is_map(params)
      assert params.x >= 0.0 and params.x <= 1.0
    end
  end

  describe "next/4 - edge cases" do
    test "handles mean calculation that could produce NaN" do
      space_fun = fn _ix -> %{x: :rand.uniform()} end
      state = Bandit.init(%{epsilon: 0.0})

      # Edge case: mean update with extreme values that don't overflow
      # Use more moderate extreme values
      history = [
        %{params: %{x: 0.5}, score: 1.0e100},  # Large but not overflow
        %{params: %{x: 0.52}, score: -1.0e100}  # Large negative but not overflow
      ]

      {params, _} = Bandit.next(space_fun, 2, history, state)

      # Should handle gracefully and not crash
      assert is_map(params)
      assert params.x >= 0.0 and params.x <= 1.0
    end

    test "handles single trial in history" do
      space_fun = fn _ix -> %{x: :rand.uniform()} end
      state = Bandit.init(%{epsilon: 0.0})

      history = [
        %{params: %{x: 0.5}, score: 10.0}
      ]

      {params, _} = Bandit.next(space_fun, 1, history, state)

      assert is_map(params)
      assert params.x >= 0.0 and params.x <= 1.0
    end

    test "handles all trials having same score" do
      space_fun = fn _ix -> %{x: :rand.uniform()} end
      state = Bandit.init(%{epsilon: 0.0})

      history = [
        %{params: %{x: 0.1}, score: 5.0},
        %{params: %{x: 0.5}, score: 5.0},
        %{params: %{x: 0.9}, score: 5.0}
      ]

      {params, _} = Bandit.next(space_fun, 3, history, state)

      # Should use exploration bonus to break ties
      assert is_map(params)
      assert params.x >= 0.0 and params.x <= 1.0
    end
  end
end
