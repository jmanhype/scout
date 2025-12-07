defmodule Scout.Pruner.SuccessiveHalvingTest do
  use ExUnit.Case, async: false  # Needs Store access

  alias Scout.Pruner.SuccessiveHalving
  alias Scout.Easy

  setup do
    # Start Store for testing
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
      state = SuccessiveHalving.init(%{})

      assert state.eta == 3
      assert state.warmup_trials == 12
      assert state.min_peers == 6
    end

    test "initializes with custom eta" do
      state = SuccessiveHalving.init(%{eta: 4})

      assert state.eta == 4
    end

    test "initializes with custom warmup_trials" do
      state = SuccessiveHalving.init(%{warmup_trials: 20})

      assert state.warmup_trials == 20
    end

    test "initializes with custom min_peers" do
      state = SuccessiveHalving.init(%{min_peers: 10})

      assert state.min_peers == 10
    end

    test "handles nil options" do
      state = SuccessiveHalving.init(nil)

      assert state.eta == 3
      assert state.warmup_trials == 12
      assert state.min_peers == 6
    end
  end

  describe "assign_bracket/2" do
    test "assigns all trials to bracket 0" do
      state = SuccessiveHalving.init(%{})

      {bracket, new_state} = SuccessiveHalving.assign_bracket(0, state)
      assert bracket == 0
      assert new_state == state

      {bracket, new_state} = SuccessiveHalving.assign_bracket(10, state)
      assert bracket == 0
      assert new_state == state
    end
  end

  describe "keep?/5 - warmup phase" do
    test "keeps all trials during warmup (< warmup_trials)" do
      study = Easy.create_study(name: "test-study", direction: :minimize)
      state = SuccessiveHalving.init(%{warmup_trials: 12})

      # Create 10 trials (below warmup threshold)
      create_trials(study.study_name, 10, :minimize)

      context = %{study_id: study.study_name, goal: :minimize, bracket: 0}
      {keep?, _} = SuccessiveHalving.keep?("trial-1", [0.5], 0, context, state)

      assert keep? == true
    end

    test "keeps trials with no scores" do
      study = Easy.create_study(name: "test-study", direction: :minimize)
      state = SuccessiveHalving.init(%{warmup_trials: 5})

      # Create enough trials to pass warmup
      create_trials(study.study_name, 15, :minimize)

      context = %{study_id: study.study_name, goal: :minimize, bracket: 0}
      {keep?, _} = SuccessiveHalving.keep?("trial-1", [], 0, context, state)

      assert keep? == true
    end
  end

  describe "keep?/5 - min_peers requirement" do
    test "keeps all trials when peers < min_peers" do
      study = Easy.create_study(name: "test-study", direction: :minimize)
      state = SuccessiveHalving.init(%{warmup_trials: 3, min_peers: 10})

      # Create 5 trials (above warmup but below min_peers)
      create_trials(study.study_name, 5, :minimize)

      context = %{study_id: study.study_name, goal: :minimize, bracket: 0}
      {keep?, _} = SuccessiveHalving.keep?("trial-1", [0.5], 0, context, state)

      assert keep? == true
    end
  end

  describe "keep?/5 - successive halving with minimize goal" do
    test "keeps top performers at rung 0" do
      study = Easy.create_study(name: "test-study", direction: :minimize)
      state = SuccessiveHalving.init(%{warmup_trials: 5, min_peers: 6, eta: 3})

      # Create 9 trials with scores: 0.1, 0.2, 0.3, ..., 0.9
      # At rung 0, keep_fraction = 3^0 = 1.0, so keep all (but we test cutoff logic)
      # At rung 1, keep_fraction = 3^-1 = 0.333, so keep top 33%
      trials = create_trials_with_scores(study.study_name, [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9])

      context = %{study_id: study.study_name, goal: :minimize, bracket: 0}

      # At rung 1 (keep_fraction = 0.333), cutoff at index 2 (keep 0.1, 0.2, 0.3)
      # Trial with score 0.2 should be kept
      {keep?, _} = SuccessiveHalving.keep?("trial-1", [0.2], 1, context, state)
      assert keep? == true

      # Trial with score 0.5 should be pruned
      {keep?, _} = SuccessiveHalving.keep?("trial-2", [0.5], 1, context, state)
      assert keep? == false
    end

    test "keeps best trials at higher rungs" do
      study = Easy.create_study(name: "test-study", direction: :minimize)
      state = SuccessiveHalving.init(%{warmup_trials: 5, min_peers: 6, eta: 3})

      # Create 18 trials
      scores = Enum.map(1..18, fn i -> i * 0.05 end)
      create_trials_with_scores(study.study_name, scores)

      context = %{study_id: study.study_name, goal: :minimize, bracket: 0}

      # At rung 2 (keep_fraction = 3^-2 = 0.111), keep top ~11% (2 out of 18)
      # Trial with score 0.05 should be kept
      {keep?, _} = SuccessiveHalving.keep?("trial-best", [0.05], 2, context, state)
      assert keep? == true

      # Trial with score 0.50 should be pruned
      {keep?, _} = SuccessiveHalving.keep?("trial-mid", [0.50], 2, context, state)
      assert keep? == false
    end
  end

  describe "keep?/5 - successive halving with maximize goal" do
    test "keeps top performers for maximization" do
      study = Easy.create_study(name: "test-study", direction: :maximize)
      state = SuccessiveHalving.init(%{warmup_trials: 5, min_peers: 6, eta: 3})

      # Create 9 trials with scores (higher is better)
      create_trials_with_scores(study.study_name, [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9])

      context = %{study_id: study.study_name, goal: :maximize, bracket: 0}

      # At rung 1 (keep_fraction = 0.333), keep top 33% (0.7, 0.8, 0.9)
      # Trial with score 0.8 should be kept
      {keep?, _} = SuccessiveHalving.keep?("trial-good", [0.8], 1, context, state)
      assert keep? == true

      # Trial with score 0.3 should be pruned
      {keep?, _} = SuccessiveHalving.keep?("trial-bad", [0.3], 1, context, state)
      assert keep? == false
    end
  end

  describe "keep?/5 - edge cases" do
    test "handles single trial" do
      study = Easy.create_study(name: "test-study", direction: :minimize)
      state = SuccessiveHalving.init(%{warmup_trials: 0, min_peers: 1})

      create_trials_with_scores(study.study_name, [0.5])

      context = %{study_id: study.study_name, goal: :minimize, bracket: 0}
      {keep?, _} = SuccessiveHalving.keep?("trial-1", [0.5], 1, context, state)

      # Single trial should be kept
      assert keep? == true
    end

    test "handles trials with multiple scores (uses last)" do
      study = Easy.create_study(name: "test-study", direction: :minimize)
      state = SuccessiveHalving.init(%{warmup_trials: 5, min_peers: 6, eta: 3})

      create_trials_with_scores(study.study_name, [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9])

      context = %{study_id: study.study_name, goal: :minimize, bracket: 0}

      # Trial improved from 0.9 to 0.15 (should use 0.15)
      {keep?, _} = SuccessiveHalving.keep?("trial-1", [0.9, 0.7, 0.5, 0.15], 1, context, state)
      assert keep? == true
    end

    test "handles boundary case at cutoff" do
      study = Easy.create_study(name: "test-study", direction: :minimize)
      state = SuccessiveHalving.init(%{warmup_trials: 5, min_peers: 6, eta: 3})

      # Create exactly 9 trials
      create_trials_with_scores(study.study_name, [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9])

      context = %{study_id: study.study_name, goal: :minimize, bracket: 0}

      # At rung 1, keep_fraction = 0.333, cutoff at index 2 (score 0.3)
      # Trial with score exactly at cutoff should be kept
      {keep?, _} = SuccessiveHalving.keep?("trial-cutoff", [0.3], 1, context, state)
      assert keep? == true
    end

    test "handles negative rung (treats as 0)" do
      study = Easy.create_study(name: "test-study", direction: :minimize)
      state = SuccessiveHalving.init(%{warmup_trials: 5, min_peers: 6})

      create_trials_with_scores(study.study_name, [0.1, 0.2, 0.3, 0.4, 0.5, 0.6])

      context = %{study_id: study.study_name, goal: :minimize, bracket: 0}

      # Negative rung should be treated as 0 (keep_fraction = 1.0)
      {keep?, _} = SuccessiveHalving.keep?("trial-1", [0.5], -1, context, state)
      assert keep? == true
    end
  end

  # Helper functions
  defp create_trials(study_id, count, goal) do
    scores = Enum.map(1..count, fn i ->
      case goal do
        :minimize -> i * 0.1
        :maximize -> (count - i + 1) * 0.1
      end
    end)

    create_trials_with_scores(study_id, scores)
  end

  defp create_trials_with_scores(study_id, scores) do
    Enum.map(scores, fn score ->
      params = %{x: :rand.uniform()}
      {:ok, trial_id} = Scout.Store.start_trial(study_id, params)
      Scout.Store.finish_trial(study_id, trial_id, score)
      trial_id
    end)
  end
end
