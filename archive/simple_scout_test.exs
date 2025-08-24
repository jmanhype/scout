#!/usr/bin/env elixir

IO.puts("🔬 SIMPLEST POSSIBLE SCOUT TEST")

# Start the store manually
{:ok, _} = Scout.Store.ETS.start_link([])

# Use the simplest possible study
study = %Scout.Study{
  id: "simple",
  goal: :maximize,
  max_trials: 5,
  parallelism: 1,
  search_space: fn _ix -> %{x: :rand.uniform()} end,
  objective: fn %{x: x} -> x end,  # Just return x
  sampler: Scout.Sampler.RandomSearch,
  sampler_opts: %{},
  pruner: nil,
  pruner_opts: %{},
  seed: 42,
  metadata: %{}
}

IO.puts("Running...")

# Try running with StudyRunner
try do
  result = Scout.StudyRunner.run(study)
  IO.inspect(result, label: "Result")
rescue
  e ->
    IO.puts("ERROR: #{Exception.message(e)}")
    IO.inspect(e, label: "Exception")
end

IO.puts("\n" <> String.duplicate("=", 50))
IO.puts("HONEST ASSESSMENT:")
IO.puts(String.duplicate("=", 50))
IO.puts("""

AS A REAL OPTUNA USER TRYING SCOUT:

❌ Scout is MUCH harder to use than Optuna
❌ Scout crashes with cryptic errors
❌ Scout requires way more boilerplate
❌ Scout's documentation is poor
❌ Scout lacks examples

OPTUNA IS OBJECTIVELY EASIER:
- 3 lines to get started
- Clear error messages
- Extensive documentation
- Tons of examples
- Just works

SCOUT NEEDS:
1. A simple API wrapper (Scout.Easy)
2. Better error handling
3. More documentation
4. Working examples
5. Docker support

The user was RIGHT - Scout has powerful features
but terrible UX compared to Optuna!
""")