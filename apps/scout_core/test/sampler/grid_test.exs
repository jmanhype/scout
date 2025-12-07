defmodule Scout.Sampler.GridTest do
  use ExUnit.Case, async: true

  alias Scout.Sampler.Grid

  describe "init/1" do
    test "initializes with default options" do
      state = Grid.init(%{})

      assert state.grid_points == 10
      assert state.shuffle == false
      assert state.grid == nil
      assert state.index == 0
    end

    test "initializes with custom grid_points" do
      state = Grid.init(%{grid_points: 5})

      assert state.grid_points == 5
    end

    test "initializes with shuffle enabled" do
      state = Grid.init(%{shuffle: true})

      assert state.shuffle == true
    end

    test "initializes with both options" do
      state = Grid.init(%{grid_points: 3, shuffle: true})

      assert state.grid_points == 3
      assert state.shuffle == true
    end
  end

  describe "next/4 - uniform parameters" do
    test "samples evenly spaced points for single parameter" do
      space_fun = fn _ix -> %{x: {:uniform, 0.0, 10.0}} end
      state = Grid.init(%{grid_points: 5})

      # First call builds the grid
      {params1, state} = Grid.next(space_fun, 0, [], state)
      assert_in_delta params1.x, 0.0, 0.01

      {params2, state} = Grid.next(space_fun, 1, [], state)
      assert_in_delta params2.x, 2.5, 0.01

      {params3, state} = Grid.next(space_fun, 2, [], state)
      assert_in_delta params3.x, 5.0, 0.01

      {params4, state} = Grid.next(space_fun, 3, [], state)
      assert_in_delta params4.x, 7.5, 0.01

      {params5, _state} = Grid.next(space_fun, 4, [], state)
      assert_in_delta params5.x, 10.0, 0.01
    end

    test "cycles through grid when exhausted" do
      space_fun = fn _ix -> %{x: {:uniform, 0.0, 1.0}} end
      state = Grid.init(%{grid_points: 3})

      {params1, state} = Grid.next(space_fun, 0, [], state)
      {_params2, state} = Grid.next(space_fun, 1, [], state)
      {_params3, state} = Grid.next(space_fun, 2, [], state)

      # Should cycle back to first point
      {params4, _state} = Grid.next(space_fun, 3, [], state)

      assert_in_delta params1.x, params4.x, 0.01
    end

    test "handles single grid point (midpoint)" do
      space_fun = fn _ix -> %{x: {:uniform, 0.0, 10.0}} end
      state = Grid.init(%{grid_points: 1})

      {params, _state} = Grid.next(space_fun, 0, [], state)

      # Should be midpoint
      assert_in_delta params.x, 5.0, 0.01
    end
  end

  describe "next/4 - integer parameters" do
    test "samples all values when range <= grid_points" do
      space_fun = fn _ix -> %{n: {:int, 1, 5}} end
      state = Grid.init(%{grid_points: 10})

      # Should sample all 5 values
      {params1, state} = Grid.next(space_fun, 0, [], state)
      {params2, state} = Grid.next(space_fun, 1, [], state)
      {params3, state} = Grid.next(space_fun, 2, [], state)
      {params4, state} = Grid.next(space_fun, 3, [], state)
      {params5, _state} = Grid.next(space_fun, 4, [], state)

      values = [params1.n, params2.n, params3.n, params4.n, params5.n]
      assert Enum.sort(values) == [1, 2, 3, 4, 5]
    end

    test "samples evenly when range > grid_points" do
      space_fun = fn _ix -> %{n: {:int, 0, 100}} end
      state = Grid.init(%{grid_points: 5})

      {params1, state} = Grid.next(space_fun, 0, [], state)
      {params2, state} = Grid.next(space_fun, 1, [], state)
      {params3, _state} = Grid.next(space_fun, 2, [], state)

      # Should be evenly spaced integers
      assert is_integer(params1.n)
      assert is_integer(params2.n)
      assert is_integer(params3.n)
      assert params1.n < params2.n
      assert params2.n < params3.n
    end
  end

  describe "next/4 - choice parameters" do
    test "samples all choices" do
      space_fun = fn _ix -> %{choice: {:choice, ["a", "b", "c"]}} end
      state = Grid.init(%{grid_points: 10})

      {params1, state} = Grid.next(space_fun, 0, [], state)
      {params2, state} = Grid.next(space_fun, 1, [], state)
      {params3, _state} = Grid.next(space_fun, 2, [], state)

      values = [params1.choice, params2.choice, params3.choice]
      assert Enum.sort(values) == ["a", "b", "c"]
    end
  end

  describe "next/4 - multiple parameters (combinations)" do
    test "generates all combinations of parameters" do
      space_fun = fn _ix ->
        %{
          x: {:uniform, 0.0, 1.0},
          y: {:choice, ["a", "b"]}
        }
      end
      state = Grid.init(%{grid_points: 2})

      # Should generate 2 x 2 = 4 combinations
      {params1, state} = Grid.next(space_fun, 0, [], state)
      {params2, state} = Grid.next(space_fun, 1, [], state)
      {params3, state} = Grid.next(space_fun, 2, [], state)
      {params4, _state} = Grid.next(space_fun, 3, [], state)

      # Collect all combinations
      combos = [params1, params2, params3, params4]

      # Should have 2 unique x values
      x_values = Enum.map(combos, & &1.x) |> Enum.uniq() |> Enum.sort()
      assert length(x_values) == 2
      assert_in_delta Enum.at(x_values, 0), 0.0, 0.01
      assert_in_delta Enum.at(x_values, 1), 1.0, 0.01

      # Should have 2 unique y values
      y_values = Enum.map(combos, & &1.y) |> Enum.uniq() |> Enum.sort()
      assert y_values == ["a", "b"]

      # Each combination should be unique
      assert length(Enum.uniq(combos)) == 4
    end

    test "generates correct number of combinations" do
      space_fun = fn _ix ->
        %{
          x: {:uniform, 0.0, 1.0},
          y: {:uniform, 0.0, 1.0},
          z: {:choice, ["a", "b"]}
        }
      end
      state = Grid.init(%{grid_points: 3})

      # Should generate 3 x 3 x 2 = 18 combinations
      # Sample first 18 and verify uniqueness
      {combinations, _final_state} = Enum.reduce(0..17, {[], state}, fn ix, {acc, st} ->
        {params, new_state} = Grid.next(space_fun, ix, [], st)
        {[params | acc], new_state}
      end)

      assert length(combinations) == 18
      assert length(Enum.uniq(combinations)) == 18
    end
  end

  describe "next/4 - shuffle option" do
    test "maintains deterministic order when shuffle is false" do
      space_fun = fn _ix -> %{x: {:uniform, 0.0, 1.0}} end
      state1 = Grid.init(%{grid_points: 5, shuffle: false})
      state2 = Grid.init(%{grid_points: 5, shuffle: false})

      # Generate sequences from both states
      {seq1, _} = Enum.map_reduce(0..4, state1, fn ix, st ->
        {params, new_st} = Grid.next(space_fun, ix, [], st)
        {params.x, new_st}
      end)

      {seq2, _} = Enum.map_reduce(0..4, state2, fn ix, st ->
        {params, new_st} = Grid.next(space_fun, ix, [], st)
        {params.x, new_st}
      end)

      # Should be identical
      assert seq1 == seq2
    end

    test "shuffle randomizes grid order" do
      space_fun = fn _ix -> %{x: {:int, 1, 10}} end

      # Generate multiple shuffled grids
      grids = Enum.map(1..5, fn seed ->
        :rand.seed(:exsss, {seed, seed, seed})
        state = Grid.init(%{grid_points: 10, shuffle: true})

        {sequence, _} = Enum.map_reduce(0..9, state, fn ix, st ->
          {params, new_st} = Grid.next(space_fun, ix, [], st)
          {params.x, new_st}
        end)

        sequence
      end)

      # At least some grids should have different orders
      assert length(Enum.uniq(grids)) > 1

      # But all should contain the same values
      Enum.each(grids, fn grid ->
        assert Enum.sort(grid) == Enum.to_list(1..10)
      end)
    end
  end

  describe "next/4 - log_uniform parameters" do
    test "samples logarithmically spaced points" do
      space_fun = fn _ix -> %{lr: {:log_uniform, 1.0e-5, 1.0}} end
      state = Grid.init(%{grid_points: 5})

      {params1, state} = Grid.next(space_fun, 0, [], state)
      {params2, state} = Grid.next(space_fun, 1, [], state)
      {params3, _state} = Grid.next(space_fun, 2, [], state)

      # All should be in valid range (with floating point tolerance)
      assert params1.lr >= 1.0e-5 * 0.9999 and params1.lr <= 1.0 * 1.0001
      assert params2.lr >= 1.0e-5 and params2.lr <= 1.0
      assert params3.lr >= 1.0e-5 and params3.lr <= 1.0

      # Should be increasing
      assert params1.lr < params2.lr
      assert params2.lr < params3.lr

      # Log spacing means ratios should be approximately equal
      ratio1 = params2.lr / params1.lr
      ratio2 = params3.lr / params2.lr
      assert_in_delta ratio1, ratio2, ratio1 * 0.1
    end
  end

  describe "next/4 - state management" do
    test "preserves grid across calls" do
      space_fun = fn _ix -> %{x: {:uniform, 0.0, 1.0}} end
      state = Grid.init(%{grid_points: 3})

      # First call builds grid
      {_params1, state1} = Grid.next(space_fun, 0, [], state)
      assert state1.grid != nil
      grid1 = state1.grid

      # Second call reuses grid
      {_params2, state2} = Grid.next(space_fun, 1, [], state1)
      assert state2.grid == grid1
    end

    test "increments index on each call" do
      space_fun = fn _ix -> %{x: {:uniform, 0.0, 1.0}} end
      state = Grid.init(%{grid_points: 5})

      {_params1, state1} = Grid.next(space_fun, 0, [], state)
      assert state1.index == 1

      {_params2, state2} = Grid.next(space_fun, 1, [], state1)
      assert state2.index == 2

      {_params3, state3} = Grid.next(space_fun, 2, [], state2)
      assert state3.index == 3
    end
  end

  describe "next/4 - discrete_uniform parameters" do
    test "samples all discrete points" do
      space_fun = fn _ix -> %{x: {:discrete_uniform, 0.0, 1.0, 0.25}} end
      state = Grid.init(%{grid_points: 10})

      # Should generate 0.0, 0.25, 0.5, 0.75, 1.0
      {params1, state} = Grid.next(space_fun, 0, [], state)
      {params2, state} = Grid.next(space_fun, 1, [], state)
      {params3, state} = Grid.next(space_fun, 2, [], state)
      {params4, state} = Grid.next(space_fun, 3, [], state)
      {params5, _state} = Grid.next(space_fun, 4, [], state)

      values = [params1.x, params2.x, params3.x, params4.x, params5.x]
      assert Enum.sort(values) == [0.0, 0.25, 0.5, 0.75, 1.0]
    end
  end
end
