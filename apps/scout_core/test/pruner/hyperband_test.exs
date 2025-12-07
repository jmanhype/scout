defmodule Scout.Pruner.HyperbandTest do
  use ExUnit.Case, async: false

  alias Scout.Pruner.Hyperband
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
      state = Hyperband.init(%{})

      assert state.eta == 3
      assert state.max_resource == 81
      # s_max = floor(log_3(81)) = floor(4) = 4
      assert state.s_max == 4
      assert state.brackets == [0, 1, 2, 3, 4]
      assert state.warmup_peers == 6
    end

    test "initializes with custom eta" do
      state = Hyperband.init(%{eta: 2})

      assert state.eta == 2
      # s_max = floor(log_2(81)) = floor(6.34) = 6
      assert state.s_max == 6
    end

    test "initializes with custom max_resource" do
      state = Hyperband.init(%{max_resource: 27})

      # s_max = floor(log_3(27)) = floor(3) = 3
      assert state.s_max == 3
      assert state.max_resource == 27
      assert state.brackets == [0, 1, 2, 3]
    end

    test "initializes with custom warmup_peers" do
      state = Hyperband.init(%{warmup_peers: 10})

      assert state.warmup_peers == 10
    end

    test "handles edge case with very small max_resource" do
      state = Hyperband.init(%{eta: 3, max_resource: 1})

      # s_max = floor(log_3(1)) = floor(0) = 0
      assert state.s_max == 0
      assert state.brackets == [0]
    end
  end

  describe "assign_bracket/2" do
    test "cycles through brackets round-robin" do
      state = Hyperband.init(%{max_resource: 27})  # 4 brackets: [0, 1, 2, 3]

      {bracket0, _} = Hyperband.assign_bracket(0, state)
      {bracket1, _} = Hyperband.assign_bracket(1, state)
      {bracket2, _} = Hyperband.assign_bracket(2, state)
      {bracket3, _} = Hyperband.assign_bracket(3, state)
      {bracket4, _} = Hyperband.assign_bracket(4, state)

      assert bracket0 == 0
      assert bracket1 == 1
      assert bracket2 == 2
      assert bracket3 == 3
      assert bracket4 == 0  # Cycles back
    end

    test "handles single bracket" do
      state = Hyperband.init(%{max_resource: 1})  # 1 bracket: [0]

      {bracket0, _} = Hyperband.assign_bracket(0, state)
      {bracket1, _} = Hyperband.assign_bracket(1, state)

      assert bracket0 == 0
      assert bracket1 == 0  # Always bracket 0
    end
  end

  describe "keep?/5 - warmup phase" do
    test "keeps all trials when no scores reported" do
      study = Easy.create_study(name: "test-study", direction: :minimize)
      state = Hyperband.init(%{})

      context = %{study_id: study.study_name, goal: :minimize, bracket: 0}
      {keep?, _} = Hyperband.keep?("trial-1", [], 0, context, state)

      assert keep? == true
    end

    test "keeps all trials when peers < warmup_peers" do
      study = Easy.create_study(name: "test-study", direction: :minimize)
      state = Hyperband.init(%{warmup_peers: 10})

      # Create only 3 observations (< warmup threshold)
      create_observations(study.study_name, 0, 0, 3)

      context = %{study_id: study.study_name, goal: :minimize, bracket: 0}
      {keep?, _} = Hyperband.keep?("trial-1", [0.5], 0, context, state)

      assert keep? == true
    end
  end

  describe "keep?/5 - successive halving with minimize goal" do
    test "keeps top 1/eta fraction of trials" do
      study = Easy.create_study(name: "test-study", direction: :minimize)
      state = Hyperband.init(%{eta: 3, warmup_peers: 6})

      # Create 9 observations at bracket 0, rung 1
      # Scores: 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9
      trial_ids = Enum.map(1..9, fn i ->
        "trial-#{i}"
      end)

      Enum.zip(trial_ids, Enum.map(1..9, fn i -> i * 0.1 end))
      |> Enum.each(fn {tid, score} ->
        Scout.Store.record_observation(study.study_name, tid, 0, 1, score)
      end)

      context = %{study_id: study.study_name, goal: :minimize, bracket: 0}

      # Top 1/3 = 3 trials should be kept (0.1, 0.2, 0.3)
      {keep?, _} = Hyperband.keep?("trial-1", [0.1], 1, context, state)
      assert keep? == true

      {keep?, _} = Hyperband.keep?("trial-3", [0.3], 1, context, state)
      assert keep? == true

      # Bottom trials should be pruned
      {keep?, _} = Hyperband.keep?("trial-5", [0.5], 1, context, state)
      assert keep? == false

      {keep?, _} = Hyperband.keep?("trial-9", [0.9], 1, context, state)
      assert keep? == false
    end
  end

  describe "keep?/5 - successive halving with maximize goal" do
    test "keeps top performers for maximization" do
      study = Easy.create_study(name: "test-study", direction: :maximize)
      state = Hyperband.init(%{eta: 3, warmup_peers: 6})

      # Create 9 observations (higher is better)
      trial_ids = Enum.map(1..9, fn i -> "trial-#{i}" end)

      Enum.zip(trial_ids, Enum.map(1..9, fn i -> i * 0.1 end))
      |> Enum.each(fn {tid, score} ->
        Scout.Store.record_observation(study.study_name, tid, 0, 1, score)
      end)

      context = %{study_id: study.study_name, goal: :maximize, bracket: 0}

      # Top 1/3 = 3 trials with highest scores (0.7, 0.8, 0.9)
      {keep?, _} = Hyperband.keep?("trial-9", [0.9], 1, context, state)
      assert keep? == true

      {keep?, _} = Hyperband.keep?("trial-7", [0.7], 1, context, state)
      assert keep? == true

      # Bottom trials should be pruned
      {keep?, _} = Hyperband.keep?("trial-1", [0.1], 1, context, state)
      assert keep? == false

      {keep?, _} = Hyperband.keep?("trial-5", [0.5], 1, context, state)
      assert keep? == false
    end
  end

  describe "keep?/5 - bracket isolation" do
    test "only considers peers from same bracket" do
      study = Easy.create_study(name: "test-study", direction: :minimize)
      state = Hyperband.init(%{eta: 3, warmup_peers: 3})

      # Create observations in bracket 0
      Enum.each(1..6, fn i ->
        Scout.Store.record_observation(study.study_name, "trial-b0-#{i}", 0, 1, i * 0.1)
      end)

      # Create observations in bracket 1
      Enum.each(1..6, fn i ->
        Scout.Store.record_observation(study.study_name, "trial-b1-#{i}", 1, 1, i * 0.1 + 5.0)
      end)

      # Trial in bracket 0 should only compare against bracket 0 peers
      context0 = %{study_id: study.study_name, goal: :minimize, bracket: 0}
      {keep?, _} = Hyperband.keep?("trial-b0-1", [0.1], 1, context0, state)
      assert keep? == true

      # Trial in bracket 1 should only compare against bracket 1 peers
      context1 = %{study_id: study.study_name, goal: :minimize, bracket: 1}
      {keep?, _} = Hyperband.keep?("trial-b1-1", [5.1], 1, context1, state)
      assert keep? == true
    end
  end

  describe "keep?/5 - edge cases" do
    test "keeps at least 1 trial even with small peer count" do
      study = Easy.create_study(name: "test-study", direction: :minimize)
      state = Hyperband.init(%{eta: 10, warmup_peers: 2})  # Very aggressive eta

      # Only 3 observations
      Scout.Store.record_observation(study.study_name, "trial-1", 0, 1, 0.1)
      Scout.Store.record_observation(study.study_name, "trial-2", 0, 1, 0.5)
      Scout.Store.record_observation(study.study_name, "trial-3", 0, 1, 0.9)

      context = %{study_id: study.study_name, goal: :minimize, bracket: 0}

      # Top 1/10 = 0.3, but we always keep at least 1
      {keep?, _} = Hyperband.keep?("trial-1", [0.1], 1, context, state)
      assert keep? == true
    end
  end

  # Helper functions
  defp create_observations(study_id, bracket, rung, count) do
    Enum.each(1..count, fn i ->
      trial_id = "trial-#{i}"
      score = i * 0.1
      Scout.Store.record_observation(study_id, trial_id, bracket, rung, score)
    end)
  end
end
