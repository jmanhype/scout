defmodule Scout.Sampler.RandomSearchTest do
  use ExUnit.Case, async: true

  alias Scout.Sampler.RandomSearch

  describe "init/1" do
    test "initializes with empty map when no opts" do
      state = RandomSearch.init(nil)
      assert is_map(state)
      assert state == %{}
    end

    test "initializes with provided opts" do
      opts = %{seed: 42}
      state = RandomSearch.init(opts)
      assert state == opts
    end
  end

  describe "next/4 - basic functionality" do
    test "samples from uniform distribution" do
      search_space = %{x: {:uniform, 0.0, 10.0}}
      state = RandomSearch.init(%{})

      {params, new_state} = RandomSearch.next(search_space, 0, [], state)

      assert is_map(params)
      assert Map.has_key?(params, :x)
      assert params.x >= 0.0
      assert params.x <= 10.0
      assert is_map(new_state)
    end

    test "samples from multiple parameters" do
      search_space = %{
        x: {:uniform, 0.0, 1.0},
        y: {:uniform, -5.0, 5.0},
        z: {:uniform, 10.0, 20.0}
      }
      state = RandomSearch.init(%{})

      {params, _} = RandomSearch.next(search_space, 0, [], state)

      assert Map.has_key?(params, :x)
      assert Map.has_key?(params, :y)
      assert Map.has_key?(params, :z)
      assert params.x >= 0.0 and params.x <= 1.0
      assert params.y >= -5.0 and params.y <= 5.0
      assert params.z >= 10.0 and params.z <= 20.0
    end

    test "samples from choice distribution" do
      search_space = %{choice: {:choice, ["a", "b", "c"]}}
      state = RandomSearch.init(%{})

      {params, _} = RandomSearch.next(search_space, 0, [], state)

      assert params.choice in ["a", "b", "c"]
    end

    test "samples from integer distribution" do
      search_space = %{n: {:int, 1, 100}}
      state = RandomSearch.init(%{})

      {params, _} = RandomSearch.next(search_space, 0, [], state)

      assert is_integer(params.n)
      assert params.n >= 1
      assert params.n <= 100
    end

    test "samples from log-uniform distribution" do
      search_space = %{lr: {:log_uniform, 1.0e-5, 1.0}}
      state = RandomSearch.init(%{})

      {params, _} = RandomSearch.next(search_space, 0, [], state)

      assert is_float(params.lr)
      assert params.lr >= 1.0e-5
      assert params.lr <= 1.0
    end
  end

  describe "next/4 - with history" do
    test "ignores history (stateless random sampling)" do
      search_space = %{x: {:uniform, 0.0, 1.0}}
      state = RandomSearch.init(%{})

      history = [
        %{params: %{x: 0.1}, score: 10.0},
        %{params: %{x: 0.9}, score: 1.0}
      ]

      {params, _} = RandomSearch.next(search_space, 2, history, state)

      # Just check it produces valid params (history is ignored)
      assert is_map(params)
      assert Map.has_key?(params, :x)
      assert params.x >= 0.0 and params.x <= 1.0
    end

    test "samples independently across trials" do
      search_space = %{x: {:uniform, 0.0, 1.0}}
      state = RandomSearch.init(%{})

      # Generate 10 samples
      samples = Enum.map(0..9, fn ix ->
        {params, _} = RandomSearch.next(search_space, ix, [], state)
        params.x
      end)

      # Should have variation (not all the same)
      assert Enum.uniq(samples) |> length() > 1

      # All should be in range
      assert Enum.all?(samples, fn x -> x >= 0.0 and x <= 1.0 end)
    end
  end

  describe "next/4 - search space function" do
    test "handles search space as function" do
      # Dynamic search space that changes based on trial index
      space_fun = fn ix ->
        if ix < 5 do
          %{x: {:uniform, 0.0, 1.0}}
        else
          %{x: {:uniform, 5.0, 10.0}}
        end
      end

      state = RandomSearch.init(%{})

      # Early trial - should sample from [0, 1]
      {params1, _} = RandomSearch.next(space_fun, 0, [], state)
      assert params1.x >= 0.0 and params1.x <= 1.0

      # Later trial - should sample from [5, 10]
      {params2, _} = RandomSearch.next(space_fun, 10, [], state)
      assert params2.x >= 5.0 and params2.x <= 10.0
    end
  end

  describe "next/4 - state preservation" do
    test "state is passed through unchanged" do
      search_space = %{x: {:uniform, 0.0, 1.0}}
      state = RandomSearch.init(%{custom_key: "value"})

      {_params, new_state} = RandomSearch.next(search_space, 0, [], state)

      # State should be preserved (RandomSearch is stateless)
      assert new_state == state
    end
  end

  describe "next/4 - parameter validity" do
    test "always generates valid parameters" do
      search_space = %{
        x: {:uniform, -100.0, 100.0},
        choice: {:choice, [1, 2, 3, 4, 5]},
        n: {:int, 0, 1000}
      }
      state = RandomSearch.init(%{})

      # Generate 100 samples to ensure validity
      Enum.each(0..99, fn ix ->
        {params, _} = RandomSearch.next(search_space, ix, [], state)

        assert params.x >= -100.0 and params.x <= 100.0
        assert params.choice in [1, 2, 3, 4, 5]
        assert is_integer(params.n)
        assert params.n >= 0 and params.n <= 1000
      end)
    end
  end
end
