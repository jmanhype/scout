# Start the application
{:ok, _} = Application.ensure_all_started(:scout)

# Load the demo module
Code.require_file("demo_study.exs")

# Create a Hyperband study
study = %Scout.Study{
  id: "demo-hyperband-#{:erlang.unique_integer([:positive])}",
  goal: :maximize,
  max_trials: 50,
  parallelism: 4,
  search_space: &DemoStudy.search_space/1,
  objective: &DemoStudy.objective/2,
  sampler: Scout.Sampler.TPE,
  sampler_opts: %{gamma: 0.25},
  pruner: Scout.Pruner.Hyperband,
  pruner_opts: %{
    min_resource: 1,
    max_resource: 10,
    reduction_factor: 3
  }
}

IO.puts("Study ID: #{study.id}")
IO.puts("Starting Hyperband optimization...")

# Run the study in background
Task.async(fn ->
  Scout.StudyRunner.run(study)
end)

IO.puts("Study running! Check dashboard at http://localhost:4050")
IO.puts("Enter study ID: #{study.id}")
Process.sleep(:infinity)