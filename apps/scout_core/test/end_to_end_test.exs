defmodule EndToEndTest do
  use ExUnit.Case
  
  @moduledoc """
  Proves the core optimization loop works end-to-end
  """

  setup do
    # Start ETS store if not already running
    case GenServer.whereis(Scout.Store.ETS) do
      nil -> start_supervised!(Scout.Store.ETS)
      _pid -> :ok
    end
    :ok
  end

  test "complete optimization flow with ETS store" do
    # 1. Create a study
    study_id = "e2e_test_#{System.unique_integer([:positive])}"
    
    study = %{
      id: study_id,
      goal: :maximize,
      max_trials: 5,
      parallelism: 1,
      search_space: %{
        x: {:uniform, -5.0, 5.0},
        y: {:uniform, -5.0, 5.0}
      },
      # Simple quadratic - maximum at (0,0)
      objective: fn params ->
        score = -(params.x * params.x + params.y * params.y)
        score
      end,
      sampler: Scout.Sampler.RandomSearch,
      sampler_opts: %{},
      seed: 12345
    }
    
    # 2. Run the executor
    assert {:ok, result} = Scout.Executor.Local.run(study)
    
    # 3. Verify we got results
    assert result.best_score != nil
    assert result.best_params != nil
    assert is_number(result.best_score)
    assert result.best_score <= 0  # Maximum is 0 at origin
    
    # 4. Verify trials were stored
    trials = Scout.Store.list_trials(study_id)
    assert length(trials) == 5
    
    # 5. Verify all trials completed
    assert Enum.all?(trials, fn t -> 
      t.status in [:succeeded, :failed]
    end)
    
    # 6. Verify best trial is actually the best
    best_stored = Enum.max_by(trials, & &1.score, fn -> nil end)
    assert best_stored != nil
    assert best_stored.score == result.best_score
  end

  test "store adapter contract is consistent" do
    study_id = "contract_test"
    trial_id = "trial_1"
    
    # Put study
    assert :ok = Scout.Store.put_study(%{id: study_id, goal: :maximize})
    
    # Get study
    assert {:ok, study} = Scout.Store.get_study(study_id)
    assert study.id == study_id
    
    # Add trial
    assert {:ok, _} = Scout.Store.add_trial(study_id, %{
      id: trial_id,
      study_id: study_id,
      params: %{x: 1.0},
      status: :running
    })
    
    # Update trial with correct arity
    assert :ok = Scout.Store.update_trial(study_id, trial_id, %{
      status: :succeeded,
      score: 0.5
    })
    
    # Fetch trial with correct arity
    assert {:ok, trial} = Scout.Store.fetch_trial(study_id, trial_id)
    assert trial.status == :succeeded
    assert trial.score == 0.5
    
    # List trials
    trials = Scout.Store.list_trials(study_id)
    assert length(trials) == 1
  end
end