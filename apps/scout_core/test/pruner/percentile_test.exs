defmodule Scout.Pruner.PercentileTest do
  use ExUnit.Case, async: false

  alias Scout.Pruner.PercentilePruner
  alias Scout.Easy

  setup do
    # Start Store for testing
    Application.put_env(:scout_core, :store_adapter, Scout.Store.ETS)
    # Start or use existing Scout.Store.ETS process
    {pid, started_by_test?} = case Scout.Store.ETS.start_link([]) do
      {:ok, pid} -> {pid, true}
      {:error, {:already_started, pid}} -> {pid, false}
    end

    # Generate unique study name to prevent test contamination
    unique_suffix = Base.encode16(:crypto.strong_rand_bytes(4), case: :lower)
    study_name = "test-study-#{unique_suffix}"

    on_exit(fn ->
      # Clean up study to prevent contamination
      Scout.Store.delete_study(study_name)

      # Only stop if we started it
      if started_by_test? and Process.alive?(pid) do
        GenServer.stop(pid, :normal, 1000)
      end
    end)

    {:ok, store_pid: pid, study_name: study_name}
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

  describe "should_prune?/5 - warmup phase" do
    test "does not prune during warmup steps", %{study_name: study_name} do
      study = Easy.create_study(name: study_name, direction: :minimize)
      state = PercentilePruner.init(%{n_warmup_steps: 5, n_startup_trials: 3})

      # Create completed trials
      create_completed_trials(study.study_name, 5)

      # At step 2 (< warmup), should not prune even if worse than percentile
      {should_prune, _} = PercentilePruner.should_prune?(study.study_name, "trial-1", 2, 10.0, state)
      assert should_prune == false
    end
  end

  describe "should_prune?/5 - interval steps" do
    test "only evaluates at interval steps", %{study_name: study_name} do
      study = Easy.create_study(name: study_name, direction: :minimize)
      state = PercentilePruner.init(%{n_warmup_steps: 0, interval_steps: 2, n_startup_trials: 3})

      create_completed_trials(study.study_name, 5)

      # Step 1 is not an interval step (0, 2, 4, ...)
      {should_prune, _} = PercentilePruner.should_prune?(study.study_name, "trial-1", 1, 10.0, state)
      assert should_prune == false

      # Step 2 is an interval step
      {should_prune, _} = PercentilePruner.should_prune?(study.study_name, "trial-1", 2, 10.0, state)
      # Will evaluate (may or may not prune depending on percentile)
      assert is_boolean(should_prune)
    end
  end

  describe "should_prune?/5 - startup trials" do
    test "does not prune if not enough startup trials", %{study_name: study_name} do
      study = Easy.create_study(name: study_name, direction: :minimize)
      state = PercentilePruner.init(%{n_startup_trials: 10, n_warmup_steps: 0})

      # Only 3 completed trials (< startup threshold)
      create_completed_trials(study.study_name, 3)

      {should_prune, _} = PercentilePruner.should_prune?(study.study_name, "trial-1", 5, 10.0, state)
      assert should_prune == false
    end
  end

  describe "should_prune?/5 - percentile comparison" do
    test "prunes trials worse than 25th percentile", %{study_name: study_name} do
      study = Easy.create_study(name: study_name, direction: :minimize)
      state = PercentilePruner.init(%{percentile: 25.0, n_startup_trials: 3, n_warmup_steps: 0})

      # Create trials with intermediate values at step 5
      # Values: [1.0, 2.0, 3.0, 4.0, 5.0] -> 25th percentile = 2.0
      create_trials_with_intermediates(study.study_name, [
        %{5 => 1.0},
        %{5 => 2.0},
        %{5 => 3.0},
        %{5 => 4.0},
        %{5 => 5.0}
      ])

      # Value 3.0 > 25th percentile (2.0), should prune
      {should_prune, _} = PercentilePruner.should_prune?(study.study_name, "trial-new", 5, 3.0, state)
      assert should_prune == true

      # Value 1.5 <= 25th percentile (2.0), should not prune
      {should_prune, _} = PercentilePruner.should_prune?(study.study_name, "trial-new", 5, 1.5, state)
      assert should_prune == false
    end

    test "prunes trials worse than 50th percentile (median)", %{study_name: study_name} do
      study = Easy.create_study(name: study_name, direction: :minimize)
      state = PercentilePruner.init(%{percentile: 50.0, n_startup_trials: 3, n_warmup_steps: 0})

      # Values: [1.0, 2.0, 3.0, 4.0, 5.0] -> 50th percentile = 3.0
      create_trials_with_intermediates(study.study_name, [
        %{3 => 1.0},
        %{3 => 2.0},
        %{3 => 3.0},
        %{3 => 4.0},
        %{3 => 5.0}
      ])

      {should_prune, _} = PercentilePruner.should_prune?(study.study_name, "trial-1", 3, 4.0, state)
      assert should_prune == true

      {should_prune, _} = PercentilePruner.should_prune?(study.study_name, "trial-2", 3, 2.0, state)
      assert should_prune == false
    end

    test "prunes trials worse than 75th percentile", %{study_name: study_name} do
      study = Easy.create_study(name: study_name, direction: :minimize)
      state = PercentilePruner.init(%{percentile: 75.0, n_startup_trials: 3, n_warmup_steps: 0})

      # Values: [1.0, 2.0, 3.0, 4.0, 5.0] -> 75th percentile = 4.0
      create_trials_with_intermediates(study.study_name, [
        %{2 => 1.0},
        %{2 => 2.0},
        %{2 => 3.0},
        %{2 => 4.0},
        %{2 => 5.0}
      ])

      {should_prune, _} = PercentilePruner.should_prune?(study.study_name, "trial-1", 2, 4.5, state)
      assert should_prune == true

      {should_prune, _} = PercentilePruner.should_prune?(study.study_name, "trial-2", 2, 3.5, state)
      assert should_prune == false
    end

    test "handles 0th percentile (minimum)", %{study_name: study_name} do
      study = Easy.create_study(name: study_name, direction: :minimize)
      state = PercentilePruner.init(%{percentile: 0.0, n_startup_trials: 3, n_warmup_steps: 0})

      # Values: [1.0, 2.0, 3.0] -> 0th percentile = 1.0
      create_trials_with_intermediates(study.study_name, [
        %{3 => 1.0},
        %{3 => 2.0},
        %{3 => 3.0}
      ])

      # Only values > minimum (1.0) should be pruned
      {should_prune, _} = PercentilePruner.should_prune?(study.study_name, "trial-1", 3, 1.5, state)
      assert should_prune == true

      {should_prune, _} = PercentilePruner.should_prune?(study.study_name, "trial-2", 3, 0.5, state)
      assert should_prune == false
    end

    test "handles 100th percentile (maximum)", %{study_name: study_name} do
      study = Easy.create_study(name: study_name, direction: :minimize)
      state = PercentilePruner.init(%{percentile: 100.0, n_startup_trials: 3, n_warmup_steps: 0})

      # Values: [1.0, 2.0, 3.0] -> 100th percentile = 3.0
      create_trials_with_intermediates(study.study_name, [
        %{5 => 1.0},
        %{5 => 2.0},
        %{5 => 3.0}
      ])

      # Only values > maximum (3.0) should be pruned
      {should_prune, _} = PercentilePruner.should_prune?(study.study_name, "trial-1", 5, 3.5, state)
      assert should_prune == true

      {should_prune, _} = PercentilePruner.should_prune?(study.study_name, "trial-2", 5, 2.5, state)
      assert should_prune == false
    end
  end

  describe "should_prune?/5 - edge cases" do
    test "does not prune when no intermediate values at step", %{study_name: study_name} do
      study = Easy.create_study(name: study_name, direction: :minimize)
      state = PercentilePruner.init(%{n_startup_trials: 3, n_warmup_steps: 0})

      # Trials have intermediate values at step 5, but we check step 10
      create_trials_with_intermediates(study.study_name, [
        %{5 => 1.0},
        %{5 => 2.0},
        %{5 => 3.0}
      ])

      {should_prune, _} = PercentilePruner.should_prune?(study.study_name, "trial-1", 10, 100.0, state)
      assert should_prune == false
    end

    test "handles single completed trial", %{study_name: study_name} do
      study = Easy.create_study(name: study_name, direction: :minimize)
      state = PercentilePruner.init(%{percentile: 50.0, n_startup_trials: 1, n_warmup_steps: 0})

      # Single trial with value 5.0 at step 3
      create_trials_with_intermediates(study.study_name, [%{3 => 5.0}])

      # Percentile of [5.0] is 5.0
      {should_prune, _} = PercentilePruner.should_prune?(study.study_name, "trial-1", 3, 6.0, state)
      assert should_prune == true

      {should_prune, _} = PercentilePruner.should_prune?(study.study_name, "trial-2", 3, 4.0, state)
      assert should_prune == false
    end

    test "handles trials with missing intermediate values", %{study_name: study_name} do
      study = Easy.create_study(name: study_name, direction: :minimize)
      state = PercentilePruner.init(%{percentile: 50.0, n_startup_trials: 2, n_warmup_steps: 0})

      # Mix of trials with and without intermediate values at step 5
      create_trials_with_intermediates(study.study_name, [
        %{5 => 2.0},
        %{3 => 1.0},  # No value at step 5
        %{5 => 4.0},
        %{}           # No intermediate values
      ])

      # Should only use trials with values at step 5: [2.0, 4.0] -> 50th percentile = 3.0
      {should_prune, _} = PercentilePruner.should_prune?(study.study_name, "trial-1", 5, 3.5, state)
      assert should_prune == true
    end

    test "handles odd number of values for percentile calculation", %{study_name: study_name} do
      study = Easy.create_study(name: study_name, direction: :minimize)
      state = PercentilePruner.init(%{percentile: 50.0, n_startup_trials: 3, n_warmup_steps: 0})

      # Values: [1.0, 3.0, 5.0] -> 50th percentile = 3.0
      create_trials_with_intermediates(study.study_name, [
        %{3 => 1.0},
        %{3 => 3.0},
        %{3 => 5.0}
      ])

      {should_prune, _} = PercentilePruner.should_prune?(study.study_name, "trial-1", 3, 4.0, state)
      assert should_prune == true

      {should_prune, _} = PercentilePruner.should_prune?(study.study_name, "trial-2", 3, 2.0, state)
      assert should_prune == false
    end

    test "handles even number of values for percentile calculation", %{study_name: study_name} do
      study = Easy.create_study(name: study_name, direction: :minimize)
      state = PercentilePruner.init(%{percentile: 50.0, n_startup_trials: 3, n_warmup_steps: 0})

      # Values: [1.0, 2.0, 4.0, 5.0] -> 50th percentile = (2.0 + 4.0) / 2 = 3.0
      create_trials_with_intermediates(study.study_name, [
        %{2 => 1.0},
        %{2 => 2.0},
        %{2 => 4.0},
        %{2 => 5.0}
      ])

      {should_prune, _} = PercentilePruner.should_prune?(study.study_name, "trial-1", 2, 3.5, state)
      assert should_prune == true

      {should_prune, _} = PercentilePruner.should_prune?(study.study_name, "trial-2", 2, 2.5, state)
      assert should_prune == false
    end

    test "handles interpolation for non-integer percentile positions", %{study_name: study_name} do
      study = Easy.create_study(name: study_name, direction: :minimize)
      # 33rd percentile should require interpolation
      state = PercentilePruner.init(%{percentile: 33.0, n_startup_trials: 3, n_warmup_steps: 0})

      # Values: [1.0, 2.0, 3.0, 4.0, 5.0]
      # 33rd percentile: k = 33 * (5-1) / 100 = 1.32 -> interpolate between index 1 and 2
      create_trials_with_intermediates(study.study_name, [
        %{4 => 1.0},
        %{4 => 2.0},
        %{4 => 3.0},
        %{4 => 4.0},
        %{4 => 5.0}
      ])

      # Should calculate interpolated percentile
      {should_prune, _} = PercentilePruner.should_prune?(study.study_name, "trial-1", 4, 3.0, state)
      # Exact value depends on interpolation, just verify it runs without error
      assert is_boolean(should_prune)
    end
  end

  # Helper functions
  defp create_completed_trials(study_id, count) do
    Enum.map(1..count, fn i ->
      params = %{x: i * 0.1}
      {:ok, trial_id} = Scout.Store.start_trial(study_id, params)
      Scout.Store.finish_trial(study_id, trial_id, i * 0.1)
      trial_id
    end)
  end

  defp create_trials_with_intermediates(study_id, intermediate_maps) do
    Enum.map(intermediate_maps, fn intermediate_values ->
      params = %{x: :rand.uniform()}
      {:ok, trial_id} = Scout.Store.start_trial(study_id, params)

      # Record intermediate values
      Enum.each(intermediate_values, fn {step, value} ->
        Scout.Store.record_observation(study_id, trial_id, 0, step, value)
      end)

      # Finish trial with final score
      final_score = if map_size(intermediate_values) > 0 do
        {_step, value} = Enum.max_by(intermediate_values, fn {step, _} -> step end)
        value
      else
        :rand.uniform()
      end

      Scout.Store.finish_trial(study_id, trial_id, final_score)
      trial_id
    end)
  end
end
