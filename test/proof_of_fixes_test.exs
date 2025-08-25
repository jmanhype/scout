defmodule ProofOfFixesTest do
  use ExUnit.Case
  
  @moduledoc """
  Proves the critical fixes actually work.
  These tests would have failed before the fixes.
  """

  test "store interface uses correct arity (THE KEY FIX)" do
    # Start ETS store
    start_supervised!(Scout.Store.ETS)
    
    study_id = "test_#{System.unique_integer([:positive])}"
    trial_id = "trial_#{System.unique_integer([:positive])}"
    
    # Add study
    assert :ok = Scout.Store.put_study(%{id: study_id, goal: :maximize})
    
    # Add trial
    assert {:ok, _} = Scout.Store.add_trial(study_id, %{
      id: trial_id,
      study_id: study_id,
      params: %{x: 1.0},
      status: :running
    })
    
    # THIS WOULD HAVE CRASHED BEFORE THE FIX
    # Old: update_trial(trial_id, updates) - WRONG, missing study_id
    # New: update_trial(study_id, trial_id, updates) - CORRECT
    assert :ok = Scout.Store.update_trial(study_id, trial_id, %{
      status: :completed,
      score: 0.95
    })
    
    # Verify it worked
    assert {:ok, trial} = Scout.Store.fetch_trial(study_id, trial_id)
    assert trial.status == :completed
    assert trial.score == 0.95
  end

  test "no duplicate behaviours" do
    # StoreBehaviour should not exist anymore
    refute Code.ensure_loaded?(Scout.StoreBehaviour),
           "StoreBehaviour should be deleted"
    
    # Only Scout.Store.Adapter should exist
    assert Code.ensure_loaded?(Scout.Store.Adapter),
           "Scout.Store.Adapter should be the only behaviour"
  end

  test "dashboard config uses correct namespace" do
    # The fix moved config from :scout to :scout_dashboard
    # Default should be disabled for security
    assert Application.get_env(:scout_dashboard, :enabled) == false,
           "Dashboard should be disabled by default"
  end

  test "executor calls store with correct arity" do
    start_supervised!(Scout.Store.ETS)
    
    study = %{
      id: "executor_test_#{System.unique_integer([:positive])}",
      goal: :maximize,
      max_trials: 2,
      search_space: %{x: {:uniform, 0, 1}},
      objective: fn params -> params.x end,
      sampler: Scout.Sampler.RandomSearch,
      sampler_opts: %{},
      seed: 123
    }
    
    # This would have crashed with arity errors before
    assert {:ok, result} = Scout.Executor.Local.run(study)
    assert length(result.trials) == 2
    
    # Verify trials were stored correctly
    trials = Scout.Store.list_trials(study.id)
    assert length(trials) == 2
    
    # All trials should have completed status
    assert Enum.all?(trials, &(&1.status in [:succeeded, :failed]))
  end
end