defmodule Scout.StoreTest do
  use ExUnit.Case, async: false

  alias Scout.Store

  setup do
    # Ensure ETS adapter is running
    case Process.whereis(Scout.Store.ETS) do
      nil ->
        {:ok, _pid} = Scout.Store.ETS.start_link([])
      _pid ->
        :ok
    end

    # Clean up any existing test data
    study_id = "test-store-#{:rand.uniform(100000)}"

    on_exit(fn ->
      Store.delete_study(study_id)
    end)

    {:ok, study_id: study_id}
  end

  describe "current_adapter/0" do
    test "returns the currently active adapter module" do
      adapter = Store.current_adapter()
      assert adapter in [Scout.Store.ETS, Scout.Store.Postgres]
    end

    test "returns explicitly configured adapter when set" do
      # Save original config
      original_adapter = Application.get_env(:scout_core, :store_adapter)

      try do
        # Set explicit adapter
        Application.put_env(:scout_core, :store_adapter, Scout.Store.ETS)
        assert Store.current_adapter() == Scout.Store.ETS
      after
        # Restore original config
        if original_adapter do
          Application.put_env(:scout_core, :store_adapter, original_adapter)
        else
          Application.delete_env(:scout_core, :store_adapter)
        end
      end
    end

    test "auto-detects Postgres adapter when Repo is configured and running" do
      # Save original configs
      original_adapter = Application.get_env(:scout_core, :store_adapter)
      original_repo_config = Application.get_env(:scout_core, Scout.Repo)

      try do
        # Remove explicit adapter setting to trigger auto-detection
        Application.delete_env(:scout_core, :store_adapter)

        # Configure Repo (simulating Postgres available scenario)
        Application.put_env(:scout_core, Scout.Repo, [
          database: "test_db",
          username: "postgres",
          password: "postgres",
          hostname: "localhost"
        ])

        # Start a mock process with the Repo name to simulate running Repo
        {:ok, mock_pid} = Agent.start_link(fn -> :ok end, name: Scout.Repo)

        # Now adapter should auto-detect Postgres
        adapter = Store.current_adapter()
        assert adapter == Scout.Store.Postgres

        # Clean up mock process
        Process.exit(mock_pid, :normal)
        Process.sleep(10)  # Give process time to exit
      after
        # Restore original configs
        if original_adapter do
          Application.put_env(:scout_core, :store_adapter, original_adapter)
        else
          Application.delete_env(:scout_core, :store_adapter)
        end

        if original_repo_config do
          Application.put_env(:scout_core, Scout.Repo, original_repo_config)
        else
          Application.delete_env(:scout_core, Scout.Repo)
        end
      end
    end

    test "falls back to ETS when Repo is configured but process not running" do
      # Save original configs
      original_adapter = Application.get_env(:scout_core, :store_adapter)
      original_repo_config = Application.get_env(:scout_core, Scout.Repo)

      try do
        # Remove explicit adapter setting
        Application.delete_env(:scout_core, :store_adapter)

        # Configure Repo but don't start the process
        Application.put_env(:scout_core, Scout.Repo, [
          database: "test_db",
          username: "postgres",
          password: "postgres",
          hostname: "localhost"
        ])

        # Ensure no Scout.Repo process is running
        case Process.whereis(Scout.Repo) do
          nil -> :ok
          pid -> Process.exit(pid, :kill)
        end
        Process.sleep(10)

        # Should fall back to ETS since Repo process not available
        adapter = Store.current_adapter()
        assert adapter == Scout.Store.ETS
      after
        # Restore original configs
        if original_adapter do
          Application.put_env(:scout_core, :store_adapter, original_adapter)
        else
          Application.delete_env(:scout_core, :store_adapter)
        end

        if original_repo_config do
          Application.put_env(:scout_core, Scout.Repo, original_repo_config)
        else
          Application.delete_env(:scout_core, Scout.Repo)
        end
      end
    end
  end

  describe "storage_mode/0" do
    test "returns :ets or :postgres depending on active adapter" do
      mode = Store.storage_mode()
      assert mode in [:ets, :postgres]
    end

    test "returns correct mode for ETS adapter" do
      # When ETS is active (default in tests)
      if Store.current_adapter() == Scout.Store.ETS do
        assert Store.storage_mode() == :ets
      end
    end

    test "returns :unknown for unrecognized adapter module" do
      # Save original config
      original_adapter = Application.get_env(:scout_core, :store_adapter)

      try do
        # Create a custom/unknown adapter module
        defmodule CustomUnknownAdapter do
          @moduledoc false
        end

        # Set unknown adapter
        Application.put_env(:scout_core, :store_adapter, CustomUnknownAdapter)

        # Should return :unknown for unrecognized adapter
        assert Store.storage_mode() == :unknown
      after
        # Restore original config
        if original_adapter do
          Application.put_env(:scout_core, :store_adapter, original_adapter)
        else
          Application.delete_env(:scout_core, :store_adapter)
        end
      end
    end
  end

  describe "child_spec/1" do
    test "returns a valid child spec from the adapter" do
      spec = Store.child_spec([])
      assert is_map(spec)
      assert Map.has_key?(spec, :id)
    end
  end

  describe "put_study/1 and get_study/1" do
    test "stores and retrieves a study", %{study_id: study_id} do
      study = %{
        id: study_id,
        name: "Test Study",
        search_space: %{x: {:uniform, 0.0, 1.0}},
        status: :running,
        created_at: DateTime.utc_now()
      }

      assert :ok = Store.put_study(study)
      assert {:ok, retrieved} = Store.get_study(study_id)
      assert retrieved.id == study_id
      assert retrieved.name == "Test Study"
    end

    test "returns :error for non-existent study" do
      assert :error = Store.get_study("nonexistent-study-#{:rand.uniform(1000000)}")
    end
  end

  describe "set_study_status/2" do
    test "updates study status", %{study_id: study_id} do
      study = %{
        id: study_id,
        name: "Status Test",
        search_space: %{x: {:uniform, 0.0, 1.0}},
        status: :running,
        created_at: DateTime.utc_now()
      }

      assert :ok = Store.put_study(study)
      assert :ok = Store.set_study_status(study_id, :paused)

      {:ok, updated} = Store.get_study(study_id)
      assert updated.status == :paused
    end
  end

  describe "start_trial/3" do
    test "creates a trial with proper state initialization", %{study_id: study_id} do
      study = %{
        id: study_id,
        name: "Trial Test",
        search_space: %{x: {:uniform, 0.0, 1.0}},
        status: :running,
        created_at: DateTime.utc_now()
      }
      Store.put_study(study)

      params = %{x: 0.5}
      assert {:ok, trial_id} = Store.start_trial(study_id, params, 0)

      # Verify trial was created with correct initial state
      assert {:ok, trial} = Store.fetch_trial(study_id, trial_id)
      assert trial.params == params
      assert trial.status == :running
      assert trial.bracket == 0
      assert is_integer(trial.started_at)
      assert is_nil(trial.score)
    end

    test "creates trial with custom bracket number", %{study_id: study_id} do
      study = %{
        id: study_id,
        name: "Bracket Test",
        search_space: %{x: {:uniform, 0.0, 1.0}},
        status: :running,
        created_at: DateTime.utc_now()
      }
      Store.put_study(study)

      params = %{x: 0.3}
      assert {:ok, trial_id} = Store.start_trial(study_id, params, 2)

      {:ok, trial} = Store.fetch_trial(study_id, trial_id)
      assert trial.bracket == 2
    end

    test "generates unique trial IDs", %{study_id: study_id} do
      study = %{
        id: study_id,
        name: "Trial ID Test",
        search_space: %{x: {:uniform, 0.0, 1.0}},
        status: :running,
        created_at: DateTime.utc_now()
      }
      Store.put_study(study)

      {:ok, trial_id_1} = Store.start_trial(study_id, %{x: 0.5}, 0)
      {:ok, trial_id_2} = Store.start_trial(study_id, %{x: 0.6}, 0)

      assert trial_id_1 != trial_id_2
      assert is_binary(trial_id_1)
      assert is_binary(trial_id_2)
    end
  end

  describe "finish_trial/4" do
    test "completes a trial with score and metrics", %{study_id: study_id} do
      study = %{
        id: study_id,
        name: "Finish Test",
        search_space: %{x: {:uniform, 0.0, 1.0}},
        status: :running,
        created_at: DateTime.utc_now()
      }
      Store.put_study(study)

      {:ok, trial_id} = Store.start_trial(study_id, %{x: 0.5}, 0)

      metrics = %{loss: 0.1, accuracy: 0.9}
      assert :ok = Store.finish_trial(study_id, trial_id, 0.5, metrics)

      {:ok, trial} = Store.fetch_trial(study_id, trial_id)
      assert trial.status == :completed
      assert trial.score == 0.5
      assert trial.metrics == metrics
      assert %DateTime{} = trial.completed_at
    end

    test "finish_trial with default empty metrics", %{study_id: study_id} do
      study = %{
        id: study_id,
        name: "Default Metrics Test",
        search_space: %{x: {:uniform, 0.0, 1.0}},
        status: :running,
        created_at: DateTime.utc_now()
      }
      Store.put_study(study)

      {:ok, trial_id} = Store.start_trial(study_id, %{x: 0.5}, 0)
      assert :ok = Store.finish_trial(study_id, trial_id, 0.8)

      {:ok, trial} = Store.fetch_trial(study_id, trial_id)
      assert trial.score == 0.8
      assert trial.metrics == %{}
    end
  end

  describe "fail_trial/3" do
    test "marks a trial as failed with error message", %{study_id: study_id} do
      study = %{
        id: study_id,
        name: "Fail Test",
        search_space: %{x: {:uniform, 0.0, 1.0}},
        status: :running,
        created_at: DateTime.utc_now()
      }
      Store.put_study(study)

      {:ok, trial_id} = Store.start_trial(study_id, %{x: 0.5}, 0)

      error_message = "Division by zero"
      assert :ok = Store.fail_trial(study_id, trial_id, error_message)

      {:ok, trial} = Store.fetch_trial(study_id, trial_id)
      assert trial.status == :failed
      assert trial.error == error_message
      assert %DateTime{} = trial.completed_at
    end
  end

  describe "prune_trial/4" do
    test "marks a trial as pruned with rung information", %{study_id: study_id} do
      study = %{
        id: study_id,
        name: "Prune Test",
        search_space: %{x: {:uniform, 0.0, 1.0}},
        status: :running,
        created_at: DateTime.utc_now()
      }
      Store.put_study(study)

      {:ok, trial_id} = Store.start_trial(study_id, %{x: 0.5}, 0)

      rung = 2
      score = 0.3
      assert :ok = Store.prune_trial(study_id, trial_id, rung, score)

      {:ok, trial} = Store.fetch_trial(study_id, trial_id)
      assert trial.status == :pruned
      assert trial.score == score
      assert trial.metadata.pruned_at_rung == rung
      assert %DateTime{} = trial.completed_at
    end

    test "prune_trial with nil score", %{study_id: study_id} do
      study = %{
        id: study_id,
        name: "Prune Nil Score Test",
        search_space: %{x: {:uniform, 0.0, 1.0}},
        status: :running,
        created_at: DateTime.utc_now()
      }
      Store.put_study(study)

      {:ok, trial_id} = Store.start_trial(study_id, %{x: 0.5}, 0)

      rung = 1
      assert :ok = Store.prune_trial(study_id, trial_id, rung)

      {:ok, trial} = Store.fetch_trial(study_id, trial_id)
      assert trial.status == :pruned
      assert is_nil(trial.score)
      assert trial.metadata.pruned_at_rung == rung
    end
  end

  describe "add_trial/2 and fetch_trial/2" do
    test "adds and retrieves a trial", %{study_id: study_id} do
      study = %{
        id: study_id,
        name: "Add Trial Test",
        search_space: %{x: {:uniform, 0.0, 1.0}},
        status: :running,
        created_at: DateTime.utc_now()
      }
      Store.put_study(study)

      trial = %{
        id: "trial-123",
        params: %{x: 0.7},
        status: :running,
        started_at: System.system_time(:millisecond),
        bracket: 0
      }

      assert {:ok, trial_id} = Store.add_trial(study_id, trial)
      assert {:ok, retrieved} = Store.fetch_trial(study_id, trial_id)
      assert retrieved.params.x == 0.7
    end

    test "returns :error for non-existent trial", %{study_id: study_id} do
      study = %{
        id: study_id,
        name: "Missing Trial Test",
        search_space: %{x: {:uniform, 0.0, 1.0}},
        status: :running,
        created_at: DateTime.utc_now()
      }
      Store.put_study(study)

      assert :error = Store.fetch_trial(study_id, "nonexistent-trial")
    end
  end

  describe "update_trial/3" do
    test "updates trial fields", %{study_id: study_id} do
      study = %{
        id: study_id,
        name: "Update Trial Test",
        search_space: %{x: {:uniform, 0.0, 1.0}},
        status: :running,
        created_at: DateTime.utc_now()
      }
      Store.put_study(study)

      {:ok, trial_id} = Store.start_trial(study_id, %{x: 0.5}, 0)

      updates = %{score: 0.75, status: :completed}
      assert :ok = Store.update_trial(study_id, trial_id, updates)

      {:ok, trial} = Store.fetch_trial(study_id, trial_id)
      assert trial.score == 0.75
      assert trial.status == :completed
    end
  end

  describe "list_trials/2" do
    test "lists all trials for a study", %{study_id: study_id} do
      study = %{
        id: study_id,
        name: "List Trials Test",
        search_space: %{x: {:uniform, 0.0, 1.0}},
        status: :running,
        created_at: DateTime.utc_now()
      }
      Store.put_study(study)

      {:ok, _} = Store.start_trial(study_id, %{x: 0.1}, 0)
      {:ok, _} = Store.start_trial(study_id, %{x: 0.2}, 0)
      {:ok, _} = Store.start_trial(study_id, %{x: 0.3}, 0)

      trials = Store.list_trials(study_id)
      assert length(trials) == 3
    end

    test "filters trials by status", %{study_id: study_id} do
      study = %{
        id: study_id,
        name: "Filter Trials Test",
        search_space: %{x: {:uniform, 0.0, 1.0}},
        status: :running,
        created_at: DateTime.utc_now()
      }
      Store.put_study(study)

      {:ok, trial_id_1} = Store.start_trial(study_id, %{x: 0.1}, 0)
      {:ok, trial_id_2} = Store.start_trial(study_id, %{x: 0.2}, 0)

      Store.finish_trial(study_id, trial_id_1, 0.5)
      # trial_id_2 remains :running

      completed_trials = Store.list_trials(study_id, status: :completed)
      running_trials = Store.list_trials(study_id, status: :running)

      # Verify that filtering works - should have at least 1 of each
      assert length(completed_trials) >= 1
      assert length(running_trials) >= 1

      # Verify the completed trial is actually trial_id_1
      assert Enum.any?(completed_trials, fn t -> t.id == trial_id_1 end)
      assert Enum.any?(running_trials, fn t -> t.id == trial_id_2 end)
    end
  end

  describe "record_observation/5" do
    test "records an observation for a trial", %{study_id: study_id} do
      study = %{
        id: study_id,
        name: "Observation Test",
        search_space: %{x: {:uniform, 0.0, 1.0}},
        status: :running,
        created_at: DateTime.utc_now()
      }
      Store.put_study(study)

      {:ok, trial_id} = Store.start_trial(study_id, %{x: 0.5}, 0)

      bracket = 0
      rung = 1
      score = 0.42

      assert :ok = Store.record_observation(study_id, trial_id, bracket, rung, score)
    end
  end

  describe "observations_at_rung/3" do
    test "retrieves observations at a specific rung", %{study_id: study_id} do
      study = %{
        id: study_id,
        name: "Rung Observations Test",
        search_space: %{x: {:uniform, 0.0, 1.0}},
        status: :running,
        created_at: DateTime.utc_now()
      }
      Store.put_study(study)

      {:ok, trial_id_1} = Store.start_trial(study_id, %{x: 0.1}, 0)
      {:ok, trial_id_2} = Store.start_trial(study_id, %{x: 0.2}, 0)

      bracket = 0
      rung = 1

      Store.record_observation(study_id, trial_id_1, bracket, rung, 0.5)
      Store.record_observation(study_id, trial_id_2, bracket, rung, 0.6)

      observations = Store.observations_at_rung(study_id, bracket, rung)
      assert length(observations) == 2
    end
  end

  describe "delete_study/1" do
    test "deletes a study and its trials" do
      study_id = "delete-test-#{:rand.uniform(100000)}"

      study = %{
        id: study_id,
        name: "Delete Test",
        search_space: %{x: {:uniform, 0.0, 1.0}},
        status: :running,
        created_at: DateTime.utc_now()
      }
      Store.put_study(study)

      {:ok, _} = Store.start_trial(study_id, %{x: 0.5}, 0)

      assert :ok = Store.delete_study(study_id)
      assert :error = Store.get_study(study_id)
    end
  end

  describe "list_studies/0" do
    test "lists all studies" do
      # Create a unique study for this test
      study_id = "list-studies-test-#{:rand.uniform(100000)}"

      study = %{
        id: study_id,
        name: "List Studies Test",
        search_space: %{x: {:uniform, 0.0, 1.0}},
        status: :running,
        created_at: DateTime.utc_now()
      }
      Store.put_study(study)

      studies = Store.list_studies()
      assert is_list(studies)
      assert Enum.any?(studies, fn s -> s.id == study_id end)

      # Clean up
      Store.delete_study(study_id)
    end
  end

  describe "health_check/0" do
    test "returns :ok when store is healthy" do
      assert :ok = Store.health_check()
    end
  end
end
