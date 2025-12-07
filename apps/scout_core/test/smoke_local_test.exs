
defmodule Scout.SmokeLocalTest do
  use ExUnit.Case, async: true

  test "local study runs deterministically with seed" do
    study = %Scout.Study{
      id: "t-#{:erlang.unique_integer([:positive])}",
      goal: :maximize,
      max_trials: 12,
      parallelism: 4,
      seed: 111,
      sampler: Scout.Sampler.Random,  # Use deterministic sampler
      sampler_opts: %{},
      pruner: nil,
      pruner_opts: %{},
      executor: Scout.Executor.Local,
      metadata: %{},
      search_space: fn _ix -> %{x: :rand.uniform()} end,
      objective: fn %{x: x} -> x end
    }
    assert {:ok, %{best_score: s1}} = Scout.StudyRunner.run(study)
    assert {:ok, %{best_score: s2}} = Scout.StudyRunner.run(study)
    assert_in_delta s1, s2, 1.0e-9
  end
end
