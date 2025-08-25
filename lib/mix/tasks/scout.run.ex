defmodule Mix.Tasks.Scout.Run do
  @moduledoc """
  Run a quick Scout optimization with recording.
  
  ## Usage
  
      mix scout.run [options]
      
  ## Options
  
      --trials N     Number of trials to run (default: 10)
      --output PATH  Output path for recording (default: tmp/scout_run.ndjson)
      --sampler NAME Sampler to use: random, tpe, grid (default: random)
      --verbose      Enable verbose output
      
  ## Example
  
      mix scout.run --trials 20 --sampler tpe --output /tmp/my_run.ndjson
  """
  
  use Mix.Task
  require Logger
  
  @shortdoc "Run a Scout optimization with recording"
  
  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args,
      strict: [
        trials: :integer,
        output: :string,
        sampler: :string,
        verbose: :boolean
      ]
    )
    
    # Start the application
    Mix.Task.run("app.start")
    
    trials = Keyword.get(opts, :trials, 10)
    output = Keyword.get(opts, :output, "tmp/scout_run_#{timestamp()}.ndjson")
    sampler_name = Keyword.get(opts, :sampler, "random")
    verbose = Keyword.get(opts, :verbose, false)
    
    if verbose do
      Logger.configure(level: :debug)
    end
    
    # Ensure output directory exists
    output
    |> Path.dirname()
    |> File.mkdir_p!()
    
    # Start recording
    {:ok, _} = Scout.Recorder.start_recording(output)
    
    Mix.shell().info("Starting Scout optimization:")
    Mix.shell().info("  Trials: #{trials}")
    Mix.shell().info("  Sampler: #{sampler_name}")
    Mix.shell().info("  Recording to: #{output}")
    Mix.shell().info("")
    
    # Define a simple test objective (Rosenbrock function)
    objective = fn params ->
      x = params["x"]
      y = params["y"]
      
      # Rosenbrock: minimize (1-x)^2 + 100*(y-x^2)^2
      term1 = :math.pow(1 - x, 2)
      term2 = 100 * :math.pow(y - x * x, 2)
      score = term1 + term2
      
      # Add some noise for realism
      score + :rand.uniform() * 0.1
    end
    
    # Define search space
    search_space = %{
      "x" => {:uniform, -2.0, 2.0},
      "y" => {:uniform, -2.0, 2.0}
    }
    
    # Select sampler
    sampler = case sampler_name do
      "tpe" -> Scout.Sampler.TPE
      "grid" -> Scout.Sampler.Grid
      _ -> Scout.Sampler.RandomSearch
    end
    
    # Create and run study
    study = %{
      id: "cli-run-#{System.unique_integer([:positive])}",
      goal: :minimize,
      max_trials: trials,
      search_space: search_space,
      objective: objective,
      sampler: sampler,
      parallelism: 1
    }
    
    start_time = System.monotonic_time(:millisecond)
    
    case Scout.Executor.Local.run(study) do
      {:ok, %{best_params: params, best_score: score}} ->
        duration = System.monotonic_time(:millisecond) - start_time
        
        Mix.shell().info("✅ Optimization complete!")
        Mix.shell().info("")
        Mix.shell().info("Best parameters:")
        Enum.each(params, fn {k, v} ->
          Mix.shell().info("  #{k}: #{Float.round(v, 4)}")
        end)
        Mix.shell().info("")
        Mix.shell().info("Best score: #{Float.round(score, 6)}")
        Mix.shell().info("Duration: #{duration}ms")
        Mix.shell().info("")
        
        # Stop recording
        Scout.Recorder.stop_recording()
        
        # Load and show summary
        events = Scout.Playback.load(output)
        summary = Scout.Playback.summary(events)
        
        Mix.shell().info("Recording summary:")
        Mix.shell().info("  Total events: #{summary.total_events}")
        Mix.shell().info("  Completed trials: #{summary.completed_trials}")
        Mix.shell().info("  Failed trials: #{summary.failed_trials}")
        Mix.shell().info("  Recording saved to: #{output}")
        
      {:error, reason} ->
        Mix.shell().error("Optimization failed: #{inspect(reason)}")
        Scout.Recorder.stop_recording()
        exit({:shutdown, 1})
    end
  end
  
  defp timestamp do
    {{y, m, d}, {h, min, s}} = :calendar.local_time()
    "#{y}#{pad(m)}#{pad(d)}_#{pad(h)}#{pad(min)}#{pad(s)}"
  end
  
  defp pad(n) when n < 10, do: "0#{n}"
  defp pad(n), do: "#{n}"
end