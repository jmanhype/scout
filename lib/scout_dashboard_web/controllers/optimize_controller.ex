defmodule ScoutDashboardWeb.OptimizeController do
  use ScoutDashboardWeb, :controller

  def run(conn, %{"study_id" => study_id}) do
    IO.puts("Starting optimization for study: #{study_id}")
    
    # Define the objective function
    objective = fn params ->
      x = params.x
      y = params.y
      # Simple quadratic function: minimize (x-2)^2 + (y-3)^2
      result = (x - 2) * (x - 2) + (y - 3) * (y - 3)
      result
    end

    # Define search space
    search_space = %{
      x: {:uniform, -5, 5},
      y: {:uniform, -5, 5}
    }

    # Run optimization in the Phoenix process context  
    try do
      result = Scout.Easy.optimize(
        objective,
        search_space,
        study_id: study_id,
        n_trials: 25,
        sampler: :tpe,
        pruner: :median,
        parallelism: 2
      )
      IO.inspect(result, label: "Optimization result")
    rescue
      e -> IO.inspect(e, label: "Optimization error")
    end

    conn
    |> put_flash(:info, "Optimization started for study #{study_id}")
    |> redirect(to: "/studies/#{study_id}")
  end
end