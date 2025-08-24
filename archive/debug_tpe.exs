# Debug TPE to see what's failing
{:ok, _} = Application.ensure_all_started(:scout)

IO.puts("Debugging TPE Sampler...")

# Initialize TPE
state = Scout.Sampler.TPE.init(%{gamma: 0.25})
IO.inspect(state, label: "TPE State")

# Create search space function
search_space_fun = fn _index ->
  %{
    x: {:uniform, -10.0, 10.0},
    y: {:uniform, -10.0, 10.0}
  }
end

# Empty history
history = []

# Try to call next
IO.puts("\nCalling TPE.next with empty history...")
try do
  result = Scout.Sampler.TPE.next(search_space_fun, 1, history, state)
  IO.inspect(result, label: "Result")
rescue
  e ->
    IO.puts("ERROR: #{inspect(e)}")
    IO.puts("Stacktrace:")
    IO.inspect(__STACKTRACE__, limit: 5)
end