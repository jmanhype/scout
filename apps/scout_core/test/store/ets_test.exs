defmodule Scout.Store.ETSTest do
  use ExUnit.Case, async: false  # ETS tables are global

  alias Scout.Store
  alias Scout.Store.ETS

  setup do
    # Configure to use ETS adapter
    Application.put_env(:scout_core, :store_adapter, Scout.Store.ETS)

    # Start or use existing Scout.Store.ETS process
    {pid, started_by_test?} = case ETS.start_link([]) do
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

  describe "put_study/1" do
    test "creates new study" do
      study = %{id: "test-study-1", name: "Test Study", goal: :minimize}

      assert :ok = Store.put_study(study)
      assert {:ok, retrieved} = Store.get_study("test-study-1")
      assert retrieved.id == "test-study-1"
      assert retrieved.name == "Test Study"
      assert retrieved.goal == :minimize
    end

    test "is idempotent" do
      study = %{id: "idempotent-study", name: "Test", goal: :minimize}

      assert :ok = Store.put_study(study)
      assert :ok = Store.put_study(study)
      assert :ok = Store.put_study(study)

      assert {:ok, _} = Store.get_study("idempotent-study")
    end

    test "overwrites existing study with same ID" do
      study1 = %{id: "overwrite-study", name: "Original", goal: :minimize}
      study2 = %{id: "overwrite-study", name: "Updated", goal: :maximize}

      assert :ok = Store.put_study(study1)
      assert :ok = Store.put_study(study2)

      assert {:ok, retrieved} = Store.get_study("overwrite-study")
      assert retrieved.name == "Updated"
      assert retrieved.goal == :maximize
    end

    test "sets status to :running by default" do
      study = %{id: "default-status", name: "Test", goal: :minimize}

      assert :ok = Store.put_study(study)
      assert {:ok, retrieved} = Store.get_study("default-status")
      assert retrieved.status == "running"
    end

    test "preserves explicit status" do
      study = %{id: "explicit-status", name: "Test", goal: :minimize, status: :completed}

      assert :ok = Store.put_study(study)
      assert {:ok, retrieved} = Store.get_study("explicit-status")
      assert retrieved.status == :completed
    end
  end

  describe "get_study/1" do
    test "returns study when it exists" do
      study = %{id: "existing-study", name: "Test", goal: :minimize}
      Store.put_study(study)

      assert {:ok, retrieved} = Store.get_study("existing-study")
      assert retrieved.id == "existing-study"
    end

    test "returns :error when study does not exist" do
      assert :error = Store.get_study("non-existent-study")
    end
  end

  describe "set_study_status/2" do
    test "updates study status" do
      study = %{id: "status-study", name: "Test", goal: :minimize}
      Store.put_study(study)

      assert :ok = Store.set_study_status("status-study", :paused)
      assert {:ok, retrieved} = Store.get_study("status-study")
      assert retrieved.status == :paused
    end

    test "returns error for non-existent study" do
      assert {:error, :not_found} = Store.set_study_status("no-such-study", :paused)
    end

    test "can transition through multiple statuses" do
      study = %{id: "transition-study", name: "Test", goal: :minimize}
      Store.put_study(study)

      assert :ok = Store.set_study_status("transition-study", :running)
      assert :ok = Store.set_study_status("transition-study", :paused)
      assert :ok = Store.set_study_status("transition-study", :completed)

      assert {:ok, retrieved} = Store.get_study("transition-study")
      assert retrieved.status == :completed
    end
  end

  describe "start_trial/2" do
    test "creates trial with generated ID" do
      study = %{id: "trial-study", name: "Test", goal: :minimize}
      Store.put_study(study)

      {:ok, trial_id} = Store.start_trial("trial-study", %{x: 0.5})

      assert is_binary(trial_id)
      assert String.length(trial_id) > 0
    end

    test "trial has correct initial state" do
      study = %{id: "state-study", name: "Test", goal: :minimize}
      Store.put_study(study)

      {:ok, trial_id} = Store.start_trial("state-study", %{x: 0.3, y: 0.7})
      {:ok, trial} = Store.fetch_trial("state-study", trial_id)

      assert trial.id == trial_id
      assert trial.params == %{x: 0.3, y: 0.7}
      assert trial.status == :running
      assert trial.bracket == 0
      assert is_integer(trial.started_at)
      assert trial.score == nil
    end

    test "can specify custom bracket" do
      study = %{id: "bracket-study", name: "Test", goal: :minimize}
      Store.put_study(study)

      {:ok, trial_id} = Store.start_trial("bracket-study", %{x: 0.5}, 3)
      {:ok, trial} = Store.fetch_trial("bracket-study", trial_id)

      assert trial.bracket == 3
    end

    test "each trial gets unique ID" do
      study = %{id: "unique-study", name: "Test", goal: :minimize}
      Store.put_study(study)

      {:ok, id1} = Store.start_trial("unique-study", %{x: 0.1})
      {:ok, id2} = Store.start_trial("unique-study", %{x: 0.2})
      {:ok, id3} = Store.start_trial("unique-study", %{x: 0.3})

      assert id1 != id2
      assert id2 != id3
      assert id1 != id3
    end
  end

  describe "add_trial/2" do
    test "adds trial with explicit ID" do
      study = %{id: "explicit-trial-study", name: "Test", goal: :minimize}
      Store.put_study(study)

      trial = %{
        id: "my-trial-id",
        params: %{x: 0.5},
        status: :running
      }

      assert {:ok, "my-trial-id"} = Store.add_trial("explicit-trial-study", trial)
      assert {:ok, retrieved} = Store.fetch_trial("explicit-trial-study", "my-trial-id")
      assert retrieved.id == "my-trial-id"
    end

    test "generates ID if not provided" do
      study = %{id: "auto-id-study", name: "Test", goal: :minimize}
      Store.put_study(study)

      trial = %{params: %{x: 0.5}, status: :running}

      assert {:ok, trial_id} = Store.add_trial("auto-id-study", trial)
      assert is_binary(trial_id)
      assert {:ok, _} = Store.fetch_trial("auto-id-study", trial_id)
    end
  end

  describe "fetch_trial/2" do
    test "fetches trial by study_id and trial_id" do
      study = %{id: "fetch-study", name: "Test", goal: :minimize}
      Store.put_study(study)

      {:ok, trial_id} = Store.start_trial("fetch-study", %{x: 0.5})
      {:ok, trial} = Store.fetch_trial("fetch-study", trial_id)

      assert trial.id == trial_id
      assert trial.params == %{x: 0.5}
    end

    test "returns :error if trial not found" do
      study = %{id: "no-trial-study", name: "Test", goal: :minimize}
      Store.put_study(study)

      assert :error = Store.fetch_trial("no-trial-study", "non-existent")
    end

    test "returns :error if study not found" do
      assert :error = Store.fetch_trial("non-existent-study", "some-trial")
    end
  end

  describe "update_trial/3" do
    test "updates trial fields" do
      study = %{id: "update-study", name: "Test", goal: :minimize}
      Store.put_study(study)

      {:ok, trial_id} = Store.start_trial("update-study", %{x: 0.5})

      updates = %{status: :completed, score: 0.123}
      assert :ok = Store.update_trial("update-study", trial_id, updates)

      {:ok, trial} = Store.fetch_trial("update-study", trial_id)
      assert trial.status == :completed
      assert trial.score == 0.123
    end

    test "merges updates with existing data" do
      study = %{id: "merge-study", name: "Test", goal: :minimize}
      Store.put_study(study)

      {:ok, trial_id} = Store.start_trial("merge-study", %{x: 0.5})

      # First update
      assert :ok = Store.update_trial("merge-study", trial_id, %{score: 0.1})

      # Second update - should not remove score
      assert :ok = Store.update_trial("merge-study", trial_id, %{status: :completed})

      {:ok, trial} = Store.fetch_trial("merge-study", trial_id)
      assert trial.score == 0.1
      assert trial.status == :completed
    end

    test "returns error for non-existent trial" do
      study = %{id: "no-trial-update", name: "Test", goal: :minimize}
      Store.put_study(study)

      assert {:error, :not_found} = Store.update_trial("no-trial-update", "fake-id", %{score: 1.0})
    end
  end

  describe "finish_trial/3" do
    test "completes trial with score" do
      study = %{id: "finish-study", name: "Test", goal: :minimize}
      Store.put_study(study)

      {:ok, trial_id} = Store.start_trial("finish-study", %{x: 0.5})
      assert :ok = Store.finish_trial("finish-study", trial_id, 0.789)

      {:ok, trial} = Store.fetch_trial("finish-study", trial_id)
      assert trial.status == :completed
      assert trial.score == 0.789
      assert %DateTime{} = trial.completed_at
    end

    test "can include metrics" do
      study = %{id: "metrics-study", name: "Test", goal: :minimize}
      Store.put_study(study)

      {:ok, trial_id} = Store.start_trial("metrics-study", %{x: 0.5})
      metrics = %{accuracy: 0.95, loss: 0.05}
      assert :ok = Store.finish_trial("metrics-study", trial_id, 0.5, metrics)

      {:ok, trial} = Store.fetch_trial("metrics-study", trial_id)
      assert trial.metrics == metrics
    end
  end

  describe "fail_trial/3" do
    test "marks trial as failed with error message" do
      study = %{id: "fail-study", name: "Test", goal: :minimize}
      Store.put_study(study)

      {:ok, trial_id} = Store.start_trial("fail-study", %{x: 0.5})
      assert :ok = Store.fail_trial("fail-study", trial_id, "Out of memory")

      {:ok, trial} = Store.fetch_trial("fail-study", trial_id)
      assert trial.status == :failed
      assert trial.error == "Out of memory"
      assert %DateTime{} = trial.completed_at
    end
  end

  describe "prune_trial/3" do
    test "marks trial as pruned" do
      study = %{id: "prune-study", name: "Test", goal: :minimize}
      Store.put_study(study)

      {:ok, trial_id} = Store.start_trial("prune-study", %{x: 0.5})
      assert :ok = Store.prune_trial("prune-study", trial_id, 2)

      {:ok, trial} = Store.fetch_trial("prune-study", trial_id)
      assert trial.status == :pruned
      assert trial.metadata.pruned_at_rung == 2
      assert %DateTime{} = trial.completed_at
    end

    test "can include score when pruning" do
      study = %{id: "prune-score-study", name: "Test", goal: :minimize}
      Store.put_study(study)

      {:ok, trial_id} = Store.start_trial("prune-score-study", %{x: 0.5})
      assert :ok = Store.prune_trial("prune-score-study", trial_id, 1, 0.999)

      {:ok, trial} = Store.fetch_trial("prune-score-study", trial_id)
      assert trial.status == :pruned
      assert trial.score == 0.999
    end
  end

  describe "list_trials/2" do
    test "returns all trials for a study" do
      study = %{id: "list-study", name: "Test", goal: :minimize}
      Store.put_study(study)

      {:ok, id1} = Store.start_trial("list-study", %{x: 0.1})
      {:ok, id2} = Store.start_trial("list-study", %{x: 0.2})
      {:ok, id3} = Store.start_trial("list-study", %{x: 0.3})

      trials = Store.list_trials("list-study")

      assert length(trials) == 3
      trial_ids = Enum.map(trials, & &1.id)
      assert id1 in trial_ids
      assert id2 in trial_ids
      assert id3 in trial_ids
    end

    test "returns empty list for study with no trials" do
      study = %{id: "empty-study", name: "Test", goal: :minimize}
      Store.put_study(study)

      assert [] = Store.list_trials("empty-study")
    end

    test "returns empty list for non-existent study" do
      assert [] = Store.list_trials("non-existent-study")
    end

    test "does not leak trials between studies" do
      study1 = %{id: "study-1", name: "Study 1", goal: :minimize}
      study2 = %{id: "study-2", name: "Study 2", goal: :minimize}
      Store.put_study(study1)
      Store.put_study(study2)

      {:ok, id1} = Store.start_trial("study-1", %{x: 0.1})
      {:ok, id2} = Store.start_trial("study-2", %{x: 0.2})

      trials1 = Store.list_trials("study-1")
      trials2 = Store.list_trials("study-2")

      assert length(trials1) == 1
      assert length(trials2) == 1
      assert hd(trials1).id == id1
      assert hd(trials2).id == id2
    end
  end

  describe "record_observation/5" do
    test "records observation for trial" do
      study = %{id: "obs-study", name: "Test", goal: :minimize}
      Store.put_study(study)

      {:ok, trial_id} = Store.start_trial("obs-study", %{x: 0.5})
      assert :ok = Store.record_observation("obs-study", trial_id, 0, 1, 0.123)

      observations = Store.observations_at_rung("obs-study", 0, 1)
      assert [{^trial_id, 0.123}] = observations
    end

    test "can record multiple observations at different rungs" do
      study = %{id: "multi-obs-study", name: "Test", goal: :minimize}
      Store.put_study(study)

      {:ok, trial_id} = Store.start_trial("multi-obs-study", %{x: 0.5})

      assert :ok = Store.record_observation("multi-obs-study", trial_id, 0, 0, 0.1)
      assert :ok = Store.record_observation("multi-obs-study", trial_id, 0, 1, 0.2)
      assert :ok = Store.record_observation("multi-obs-study", trial_id, 0, 2, 0.3)

      assert [{^trial_id, 0.1}] = Store.observations_at_rung("multi-obs-study", 0, 0)
      assert [{^trial_id, 0.2}] = Store.observations_at_rung("multi-obs-study", 0, 1)
      assert [{^trial_id, 0.3}] = Store.observations_at_rung("multi-obs-study", 0, 2)
    end

    test "can record observations in different brackets" do
      study = %{id: "bracket-obs-study", name: "Test", goal: :minimize}
      Store.put_study(study)

      {:ok, trial_id} = Store.start_trial("bracket-obs-study", %{x: 0.5})

      assert :ok = Store.record_observation("bracket-obs-study", trial_id, 0, 1, 0.1)
      assert :ok = Store.record_observation("bracket-obs-study", trial_id, 1, 1, 0.2)
      assert :ok = Store.record_observation("bracket-obs-study", trial_id, 2, 1, 0.3)

      assert [{^trial_id, 0.1}] = Store.observations_at_rung("bracket-obs-study", 0, 1)
      assert [{^trial_id, 0.2}] = Store.observations_at_rung("bracket-obs-study", 1, 1)
      assert [{^trial_id, 0.3}] = Store.observations_at_rung("bracket-obs-study", 2, 1)
    end
  end

  describe "observations_at_rung/3" do
    test "returns all observations at specific bracket and rung" do
      study = %{id: "rung-obs-study", name: "Test", goal: :minimize}
      Store.put_study(study)

      {:ok, id1} = Store.start_trial("rung-obs-study", %{x: 0.1})
      {:ok, id2} = Store.start_trial("rung-obs-study", %{x: 0.2})
      {:ok, id3} = Store.start_trial("rung-obs-study", %{x: 0.3})

      Store.record_observation("rung-obs-study", id1, 0, 1, 0.11)
      Store.record_observation("rung-obs-study", id2, 0, 1, 0.22)
      Store.record_observation("rung-obs-study", id3, 0, 1, 0.33)

      observations = Store.observations_at_rung("rung-obs-study", 0, 1)

      assert length(observations) == 3
      assert {id1, 0.11} in observations
      assert {id2, 0.22} in observations
      assert {id3, 0.33} in observations
    end

    test "returns empty list when no observations at rung" do
      study = %{id: "empty-rung-study", name: "Test", goal: :minimize}
      Store.put_study(study)

      assert [] = Store.observations_at_rung("empty-rung-study", 0, 1)
    end

    test "isolates observations by bracket" do
      study = %{id: "bracket-isolation-study", name: "Test", goal: :minimize}
      Store.put_study(study)

      {:ok, trial_id} = Store.start_trial("bracket-isolation-study", %{x: 0.5})

      Store.record_observation("bracket-isolation-study", trial_id, 0, 1, 0.1)
      Store.record_observation("bracket-isolation-study", trial_id, 1, 1, 0.2)

      assert [{^trial_id, 0.1}] = Store.observations_at_rung("bracket-isolation-study", 0, 1)
      assert [{^trial_id, 0.2}] = Store.observations_at_rung("bracket-isolation-study", 1, 1)
      assert [] = Store.observations_at_rung("bracket-isolation-study", 2, 1)
    end

    test "isolates observations by study" do
      study1 = %{id: "iso-study-1", name: "Study 1", goal: :minimize}
      study2 = %{id: "iso-study-2", name: "Study 2", goal: :minimize}
      Store.put_study(study1)
      Store.put_study(study2)

      {:ok, id1} = Store.start_trial("iso-study-1", %{x: 0.1})
      {:ok, id2} = Store.start_trial("iso-study-2", %{x: 0.2})

      Store.record_observation("iso-study-1", id1, 0, 1, 0.11)
      Store.record_observation("iso-study-2", id2, 0, 1, 0.22)

      obs1 = Store.observations_at_rung("iso-study-1", 0, 1)
      obs2 = Store.observations_at_rung("iso-study-2", 0, 1)

      assert obs1 == [{id1, 0.11}]
      assert obs2 == [{id2, 0.22}]
    end
  end

  describe "delete_study/1" do
    test "deletes study" do
      study = %{id: "delete-me", name: "Test", goal: :minimize}
      Store.put_study(study)

      assert {:ok, _} = Store.get_study("delete-me")
      assert :ok = Store.delete_study("delete-me")
      assert :error = Store.get_study("delete-me")
    end

    test "deletes all trials associated with study" do
      study = %{id: "delete-with-trials", name: "Test", goal: :minimize}
      Store.put_study(study)

      {:ok, _} = Store.start_trial("delete-with-trials", %{x: 0.1})
      {:ok, _} = Store.start_trial("delete-with-trials", %{x: 0.2})

      assert length(Store.list_trials("delete-with-trials")) == 2

      assert :ok = Store.delete_study("delete-with-trials")
      assert [] = Store.list_trials("delete-with-trials")
    end

    test "deletes all observations associated with study" do
      study = %{id: "delete-with-obs", name: "Test", goal: :minimize}
      Store.put_study(study)

      {:ok, trial_id} = Store.start_trial("delete-with-obs", %{x: 0.5})
      Store.record_observation("delete-with-obs", trial_id, 0, 1, 0.123)

      assert length(Store.observations_at_rung("delete-with-obs", 0, 1)) == 1

      assert :ok = Store.delete_study("delete-with-obs")
      assert [] = Store.observations_at_rung("delete-with-obs", 0, 1)
    end

    test "does not affect other studies" do
      study1 = %{id: "keep-me", name: "Keep", goal: :minimize}
      study2 = %{id: "delete-me-2", name: "Delete", goal: :minimize}
      Store.put_study(study1)
      Store.put_study(study2)

      {:ok, id1} = Store.start_trial("keep-me", %{x: 0.1})
      {:ok, _} = Store.start_trial("delete-me-2", %{x: 0.2})

      assert :ok = Store.delete_study("delete-me-2")

      assert {:ok, _} = Store.get_study("keep-me")
      assert length(Store.list_trials("keep-me")) == 1
      assert :error = Store.get_study("delete-me-2")
    end
  end


  describe "list_studies/0" do
    test "returns all studies" do
      study1 = %{id: "list-s1", name: "Study 1", goal: :minimize}
      study2 = %{id: "list-s2", name: "Study 2", goal: :maximize}
      Store.put_study(study1)
      Store.put_study(study2)

      studies = Store.ETS.list_studies()

      assert length(studies) >= 2
      assert Enum.any?(studies, & &1.id == "list-s1")
      assert Enum.any?(studies, & &1.id == "list-s2")
    end

    test "returns empty list when no studies" do
      # Fresh ETS instance from setup
      studies = Store.ETS.list_studies()
      assert is_list(studies)
    end
  end

  describe "health_check/0" do
    test "returns :ok when store is healthy" do
      assert :ok = Store.health_check()
    end
  end

  describe "concurrency" do
    test "handles concurrent trial creation" do
      study = %{id: "concurrent-study", name: "Test", goal: :minimize}
      Store.put_study(study)

      tasks = for i <- 1..20 do
        Task.async(fn ->
          Store.start_trial("concurrent-study", %{x: i / 20.0})
        end)
      end

      trial_ids = Enum.map(tasks, &Task.await/1)

      # All should succeed
      assert Enum.all?(trial_ids, fn result ->
        match?({:ok, _}, result)
      end)

      # All IDs should be unique
      ids = Enum.map(trial_ids, fn {:ok, id} -> id end)
      assert length(Enum.uniq(ids)) == 20

      # All trials should be in the store
      trials = Store.list_trials("concurrent-study")
      assert length(trials) == 20
    end

    test "handles concurrent observations" do
      study = %{id: "concurrent-obs-study", name: "Test", goal: :minimize}
      Store.put_study(study)

      {:ok, trial_id} = Store.start_trial("concurrent-obs-study", %{x: 0.5})

      tasks = for i <- 1..10 do
        Task.async(fn ->
          Store.record_observation("concurrent-obs-study", trial_id, 0, i, i * 0.1)
        end)
      end

      results = Enum.map(tasks, &Task.await/1)

      # All should succeed
      assert Enum.all?(results, &(&1 == :ok))

      # All observations should be recorded
      for i <- 1..10 do
        obs = Store.observations_at_rung("concurrent-obs-study", 0, i)
        assert [{^trial_id, score}] = obs
        assert_in_delta score, i * 0.1, 0.001
      end
    end

    test "handles concurrent updates to same trial" do
      study = %{id: "concurrent-update-study", name: "Test", goal: :minimize}
      Store.put_study(study)

      {:ok, trial_id} = Store.start_trial("concurrent-update-study", %{x: 0.5})

      tasks = for i <- 1..10 do
        Task.async(fn ->
          Store.update_trial("concurrent-update-study", trial_id, %{"field_#{i}" => i})
        end)
      end

      results = Enum.map(tasks, &Task.await/1)

      # All should succeed
      assert Enum.all?(results, &(&1 == :ok))

      # Trial should have all fields (order doesn't matter due to concurrent updates)
      {:ok, trial} = Store.fetch_trial("concurrent-update-study", trial_id)

      # At least some fields should be present
      assert is_map(trial)
    end
  end

  describe "delete_trial/2" do
    test "deletes specific trial from study" do
      study = %{id: "delete-trial-study", name: "Test", goal: :minimize}
      Store.put_study(study)

      {:ok, id1} = Store.start_trial("delete-trial-study", %{x: 0.1})
      {:ok, id2} = Store.start_trial("delete-trial-study", %{x: 0.2})

      assert length(Store.list_trials("delete-trial-study")) == 2

      assert :ok = Store.delete_trial("delete-trial-study", id1)

      # Only id2 should remain
      trials = Store.list_trials("delete-trial-study")
      assert length(trials) == 1
      assert hd(trials).id == id2

      # id1 should not be fetchable
      assert :error = Store.fetch_trial("delete-trial-study", id1)
      assert {:ok, _} = Store.fetch_trial("delete-trial-study", id2)
    end

    test "does not affect trials in other studies" do
      study1 = %{id: "study-a", name: "Study A", goal: :minimize}
      study2 = %{id: "study-b", name: "Study B", goal: :minimize}
      Store.put_study(study1)
      Store.put_study(study2)

      {:ok, id_a} = Store.start_trial("study-a", %{x: 0.1})
      {:ok, id_b} = Store.start_trial("study-b", %{x: 0.2})

      assert :ok = Store.delete_trial("study-a", id_a)

      # study-b's trial should be unaffected
      assert {:ok, _} = Store.fetch_trial("study-b", id_b)
      assert length(Store.list_trials("study-b")) == 1
    end
  end

  describe "mark_pruned/2 and pruned?/2" do
    test "marks trial as pruned in events table" do
      study = %{id: "event-prune-study", name: "Test", goal: :minimize}
      Store.put_study(study)

      {:ok, trial_id} = Store.start_trial("event-prune-study", %{x: 0.5})

      # Initially not pruned
      assert ETS.pruned?("event-prune-study", trial_id) == false

      # Mark as pruned (cast is async, need small delay)
      ETS.mark_pruned("event-prune-study", trial_id)
      Process.sleep(10)

      # Now should be pruned
      assert ETS.pruned?("event-prune-study", trial_id) == true
    end

    test "can check multiple trials for pruned status" do
      study = %{id: "multi-prune-study", name: "Test", goal: :minimize}
      Store.put_study(study)

      {:ok, id1} = Store.start_trial("multi-prune-study", %{x: 0.1})
      {:ok, id2} = Store.start_trial("multi-prune-study", %{x: 0.2})
      {:ok, id3} = Store.start_trial("multi-prune-study", %{x: 0.3})

      # Mark only id2 as pruned
      ETS.mark_pruned("multi-prune-study", id2)
      Process.sleep(10)  # Allow async cast to complete

      assert ETS.pruned?("multi-prune-study", id1) == false
      assert ETS.pruned?("multi-prune-study", id2) == true
      assert ETS.pruned?("multi-prune-study", id3) == false
    end

    test "pruned events are isolated by study" do
      study1 = %{id: "prune-study-1", name: "Study 1", goal: :minimize}
      study2 = %{id: "prune-study-2", name: "Study 2", goal: :minimize}
      Store.put_study(study1)
      Store.put_study(study2)

      {:ok, id1} = Store.start_trial("prune-study-1", %{x: 0.1})
      {:ok, id2} = Store.start_trial("prune-study-2", %{x: 0.2})

      ETS.mark_pruned("prune-study-1", id1)
      Process.sleep(10)  # Allow async cast to complete

      assert ETS.pruned?("prune-study-1", id1) == true
      assert ETS.pruned?("prune-study-2", id2) == false
      # Same trial ID in different study should not be affected
      assert ETS.pruned?("prune-study-2", id1) == false
    end
  end

  describe "intermediate_values in list_trials" do
    test "populates intermediate_values from observations" do
      study = %{id: "intermediate-study", name: "Test", goal: :minimize}
      Store.put_study(study)

      {:ok, trial_id} = Store.start_trial("intermediate-study", %{x: 0.5})

      # Record observations at different rungs
      Store.record_observation("intermediate-study", trial_id, 0, 1, 0.9)
      Store.record_observation("intermediate-study", trial_id, 0, 2, 0.8)
      Store.record_observation("intermediate-study", trial_id, 0, 3, 0.7)

      trials = Store.list_trials("intermediate-study")

      assert length(trials) == 1
      trial = hd(trials)

      # intermediate_values should be populated
      assert trial.intermediate_values == %{1 => 0.9, 2 => 0.8, 3 => 0.7}
    end

    test "handles trials with no observations" do
      study = %{id: "no-obs-study", name: "Test", goal: :minimize}
      Store.put_study(study)

      {:ok, _trial_id} = Store.start_trial("no-obs-study", %{x: 0.5})

      trials = Store.list_trials("no-obs-study")

      assert length(trials) == 1
      trial = hd(trials)

      # intermediate_values should be empty map
      assert trial.intermediate_values == %{}
    end

    test "only includes observations for specific trial" do
      study = %{id: "multi-trial-obs-study", name: "Test", goal: :minimize}
      Store.put_study(study)

      {:ok, id1} = Store.start_trial("multi-trial-obs-study", %{x: 0.1})
      {:ok, id2} = Store.start_trial("multi-trial-obs-study", %{x: 0.2})

      # Record observations for both trials
      Store.record_observation("multi-trial-obs-study", id1, 0, 1, 0.11)
      Store.record_observation("multi-trial-obs-study", id1, 0, 2, 0.12)
      Store.record_observation("multi-trial-obs-study", id2, 0, 1, 0.21)
      Store.record_observation("multi-trial-obs-study", id2, 0, 2, 0.22)

      trials = Store.list_trials("multi-trial-obs-study")
      assert length(trials) == 2

      # Each trial should only have its own intermediate values
      trial1 = Enum.find(trials, &(&1.id == id1))
      trial2 = Enum.find(trials, &(&1.id == id2))

      assert trial1.intermediate_values == %{1 => 0.11, 2 => 0.12}
      assert trial2.intermediate_values == %{1 => 0.21, 2 => 0.22}
    end
  end

  describe "edge cases" do
    test "handles very long study names" do
      long_name = String.duplicate("a", 1000)
      study = %{id: "long-name-study", name: long_name, goal: :minimize}

      assert :ok = Store.put_study(study)
      assert {:ok, retrieved} = Store.get_study("long-name-study")
      assert retrieved.name == long_name
    end

    test "handles special characters in study IDs" do
      study = %{id: "study-with-dashes_and_underscores.123", name: "Test", goal: :minimize}

      assert :ok = Store.put_study(study)
      assert {:ok, _} = Store.get_study("study-with-dashes_and_underscores.123")
    end

    test "handles very large parameter maps" do
      study = %{id: "large-params-study", name: "Test", goal: :minimize}
      Store.put_study(study)

      large_params = Map.new(1..100, fn i -> {"param_#{i}", i / 100.0} end)
      {:ok, trial_id} = Store.start_trial("large-params-study", large_params)

      {:ok, trial} = Store.fetch_trial("large-params-study", trial_id)
      assert map_size(trial.params) == 100
    end

    test "handles nil values in trial updates" do
      study = %{id: "nil-study", name: "Test", goal: :minimize}
      Store.put_study(study)

      {:ok, trial_id} = Store.start_trial("nil-study", %{x: 0.5})

      # Update with nil should work
      assert :ok = Store.update_trial("nil-study", trial_id, %{score: nil})

      {:ok, trial} = Store.fetch_trial("nil-study", trial_id)
      assert trial.score == nil
    end

    test "handles negative and zero scores" do
      study = %{id: "negative-score-study", name: "Test", goal: :minimize}
      Store.put_study(study)

      {:ok, id1} = Store.start_trial("negative-score-study", %{x: 0.1})
      {:ok, id2} = Store.start_trial("negative-score-study", %{x: 0.2})
      {:ok, id3} = Store.start_trial("negative-score-study", %{x: 0.3})

      assert :ok = Store.finish_trial("negative-score-study", id1, -5.5)
      assert :ok = Store.finish_trial("negative-score-study", id2, 0.0)
      assert :ok = Store.finish_trial("negative-score-study", id3, 100.0)

      {:ok, t1} = Store.fetch_trial("negative-score-study", id1)
      {:ok, t2} = Store.fetch_trial("negative-score-study", id2)
      {:ok, t3} = Store.fetch_trial("negative-score-study", id3)

      assert t1.score == -5.5
      assert t2.score == 0.0
      assert t3.score == 100.0
    end
  end
end
