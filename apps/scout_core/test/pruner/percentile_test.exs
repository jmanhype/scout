defmodule Scout.Pruner.PercentileTest do
  use ExUnit.Case, async: false

  alias Scout.Pruner.PercentilePruner
  alias Scout.Easy

  setup do
    Application.put_env(:scout_core, :store_adapter, Scout.Store.ETS)
    # Start or use existing Scout.Store.ETS process
    {pid, started_by_test?} = case Scout.Store.ETS.start_link([]) do
      {:ok, pid} -> {pid, true}
      {:error, {:already_started, pid}} -> {pid, false}
    end

    on_exit(fn ->
      # Only stop if we started it
      if started_by_test? and Process.alive?(pid) do
        GenServer.stop(pid, :normal, 1000)
      end
    end)

    {:ok, store_pid: pid}
  end

  describe "init/1" do
    test "initializes with default options" do
      state = PercentilePruner.init(%{})

      assert state.percentile == 25.0
      assert state.n_startup_trials == 5
      assert state.n_warmup_steps == 0
      assert state.interval_steps == 1
    end

    test "initializes with custom percentile" do
      state = PercentilePruner.init(%{percentile: 75.0})

      assert state.percentile == 75.0
    end

    test "initializes with all custom options" do
      state = PercentilePruner.init(%{
        percentile: 50.0,
        n_startup_trials: 10,
        n_warmup_steps: 3,
        interval_steps: 2
      })

      assert state.percentile == 50.0
      assert state.n_startup_trials == 10
      assert state.n_warmup_steps == 3
      assert state.interval_steps == 2
    end
  end

  describe "assign_bracket/2" do
    test "assigns all trials to bracket 0" do
      state = PercentilePruner.init(%{})

      {bracket, new_state} = PercentilePruner.assign_bracket(0, state)
      assert bracket == 0
      assert new_state == state
    end
  end

  describe "keep?/5" do
    test "always returns true (dummy implementation)" do
      state = PercentilePruner.init(%{})

      {keep?, new_state} = PercentilePruner.keep?("study", "trial", 0, 1, state)
      assert keep? == true
      assert new_state == state
    end
  end

  describe "should_prune?/5 - validation" do
    test "raises error for invalid percentile < 0" do
      state = PercentilePruner.init(%{percentile: -5.0})

      assert_raise ArgumentError, ~r/Percentile must be between 0 and 100/, fn ->
        PercentilePruner.should_prune?("study", "trial", 5, 1.0, state)
      end
    end

    test "raises error for invalid percentile > 100" do
      state = PercentilePruner.init(%{percentile: 150.0})

      assert_raise ArgumentError, ~r/Percentile must be between 0 and 100/, fn ->
        PercentilePruner.should_prune?("study", "trial", 5, 1.0, state)
      end
    end
  end

  describe "should_prune?/5 - warmup and intervals" do
    test "does not prune during warmup steps" do
      study = Easy.create_study(name: "test-study", direction: :minimize)
      state = PercentilePruner.init(%{n_warmup_steps: 5, n_startup_trials: 0})

      {should_prune, _} = PercentilePruner.should_prune?(study.study_name, "trial-1", 2, 10.0, state)
      assert should_prune == false
    end

    test "does not prune if not enough startup trials" do
      study = Easy.create_study(name: "test-study", direction: :minimize)
      state = PercentilePruner.init(%{n_startup_trials: 10, n_warmup_steps: 0})

      {should_prune, _} = PercentilePruner.should_prune?(study.study_name, "trial-1", 5, 10.0, state)
      assert should_prune == false
    end
  end
end
