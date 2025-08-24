defmodule ScoutDashboardWeb.VisualizationsLive do
  @moduledoc """
  Enhanced visualizations for Scout optimization studies.
  
  Provides:
  - Parallel coordinates plot for hyperparameter visualization
  - Optimization history heatmap
  - Parameter importance analysis
  - Convergence plots
  """
  
  use ScoutDashboardWeb, :live_view
  alias Scout.Store
  
  @impl true
  def mount(%{"study_id" => study_id}, _session, socket) do
    if connected?(socket) do
      # Subscribe to study updates
      Phoenix.PubSub.subscribe(ScoutDashboard.PubSub, "study:#{study_id}")
      # Start periodic updates
      :timer.send_interval(2000, :refresh)
    end
    
    {:ok, 
     socket
     |> assign(:study_id, study_id)
     |> assign(:page_title, "Visualizations - #{study_id}")
     |> load_study_data()}
  end
  
  @impl true
  def handle_info(:refresh, socket) do
    {:noreply, load_study_data(socket)}
  end
  
  @impl true
  def handle_info({:trial_complete, _trial}, socket) do
    {:noreply, load_study_data(socket)}
  end
  
  defp load_study_data(socket) do
    study_id = socket.assigns.study_id
    
    case Store.get_study(study_id) do
      {:ok, study} ->
        trials = Store.list_trials(study_id)
        
        socket
        |> assign(:study, study)
        |> assign(:trials, trials)
        |> assign(:parallel_coords_data, prepare_parallel_coords(trials))
        |> assign(:heatmap_data, prepare_heatmap(trials))
        |> assign(:importance_data, calculate_importance(trials))
        |> assign(:convergence_data, prepare_convergence(trials))
        
      _ ->
        assign(socket, :error, "Study not found")
    end
  end
  
  # Prepare data for parallel coordinates plot
  defp prepare_parallel_coords(trials) do
    completed_trials = Enum.filter(trials, &(&1[:status] in [:succeeded, "succeeded"]))
    
    if Enum.empty?(completed_trials) do
      nil
    else
      # Extract parameter names
      first_trial = List.first(completed_trials)
      param_names = Map.keys(first_trial[:params] || %{})
      
      # Format data for visualization
      %{
        dimensions: param_names,
        data: Enum.map(completed_trials, fn trial ->
          %{
            params: trial[:params],
            value: trial[:value],
            color: color_for_value(trial[:value], completed_trials)
          }
        end)
      }
    end
  end
  
  # Prepare optimization history heatmap
  defp prepare_heatmap(trials) do
    completed_trials = trials
      |> Enum.filter(&(&1[:status] in [:succeeded, "succeeded"]))
      |> Enum.sort_by(&(&1[:number] || 0))
    
    if length(completed_trials) < 2 do
      nil
    else
      # Group trials into buckets for heatmap
      bucket_size = max(1, div(length(completed_trials), 20))
      
      buckets = completed_trials
        |> Enum.chunk_every(bucket_size)
        |> Enum.with_index()
        |> Enum.map(fn {bucket, idx} ->
          values = Enum.map(bucket, & &1[:value])
          %{
            bucket: idx,
            min: Enum.min(values),
            max: Enum.max(values),
            mean: Enum.sum(values) / length(values),
            count: length(bucket)
          }
        end)
      
      %{
        buckets: buckets,
        total_trials: length(completed_trials)
      }
    end
  end
  
  # Calculate parameter importance using variance analysis
  defp calculate_importance(trials) do
    completed_trials = Enum.filter(trials, &(&1[:status] in [:succeeded, "succeeded"]))
    
    if length(completed_trials) < 5 do
      nil
    else
      # Get parameter names
      param_names = completed_trials
        |> List.first()
        |> Map.get(:params, %{})
        |> Map.keys()
      
      # Calculate correlation between each parameter and objective value
      importances = Enum.map(param_names, fn param ->
        values = Enum.map(completed_trials, & &1[:value])
        params = Enum.map(completed_trials, & get_in(&1, [:params, param]))
        
        correlation = calculate_correlation(params, values)
        
        %{
          parameter: param,
          importance: abs(correlation),
          correlation: correlation
        }
      end)
      
      # Sort by importance
      Enum.sort_by(importances, & &1.importance, :desc)
    end
  end
  
  # Prepare convergence plot data
  defp prepare_convergence(trials) do
    completed_trials = trials
      |> Enum.filter(&(&1[:status] in [:succeeded, "succeeded"]))
      |> Enum.sort_by(&(&1[:number] || 0))
    
    if Enum.empty?(completed_trials) do
      nil
    else
      {best_values, _} = Enum.map_reduce(completed_trials, nil, fn trial, best ->
        current_value = trial[:value]
        new_best = if best == nil or current_value < best, do: current_value, else: best
        {new_best, new_best}
      end)
      
      Enum.zip(1..length(best_values), best_values)
        |> Enum.map(fn {x, y} -> %{trial: x, best_value: y} end)
    end
  end
  
  # Helper: Calculate correlation coefficient
  defp calculate_correlation(xs, ys) when length(xs) == length(ys) do
    n = length(xs)
    
    if n < 2 do
      0.0
    else
      # Convert to floats
      xs = Enum.map(xs, &to_float/1)
      ys = Enum.map(ys, &to_float/1)
      
      mean_x = Enum.sum(xs) / n
      mean_y = Enum.sum(ys) / n
      
      covariance = Enum.zip(xs, ys)
        |> Enum.map(fn {x, y} -> (x - mean_x) * (y - mean_y) end)
        |> Enum.sum()
        |> Kernel./(n)
      
      std_x = :math.sqrt(Enum.sum(Enum.map(xs, fn x -> :math.pow(x - mean_x, 2) end)) / n)
      std_y = :math.sqrt(Enum.sum(Enum.map(ys, fn y -> :math.pow(y - mean_y, 2) end)) / n)
      
      if std_x == 0 or std_y == 0 do
        0.0
      else
        covariance / (std_x * std_y)
      end
    end
  end
  defp calculate_correlation(_, _), do: 0.0
  
  defp to_float(n) when is_float(n), do: n
  defp to_float(n) when is_integer(n), do: n * 1.0
  defp to_float(_), do: 0.0
  
  # Helper: Color gradient for values
  defp color_for_value(value, all_trials) do
    values = Enum.map(all_trials, & &1[:value])
    min_val = Enum.min(values)
    max_val = Enum.max(values)
    
    if max_val == min_val do
      "#3b82f6"  # Blue if all values are the same
    else
      # Normalize to 0-1
      normalized = (value - min_val) / (max_val - min_val)
      
      # Gradient from blue (good) to red (bad)
      if normalized < 0.5 do
        "#3b82f6"  # Blue for good values
      else
        "#ef4444"  # Red for bad values
      end
    end
  end
  
  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <div class="mb-8">
        <h1 class="text-3xl font-bold text-gray-900">
          Visualizations: <%= @study_id %>
        </h1>
        <div class="mt-2 flex items-center space-x-4">
          <.link navigate={~p"/studies/#{@study_id}"} class="text-blue-600 hover:text-blue-800">
            ← Back to Study
          </.link>
        </div>
      </div>
      
      <%= if assigns[:error] do %>
        <div class="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded">
          <%= @error %>
        </div>
      <% else %>
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <!-- Convergence Plot -->
          <div class="bg-white rounded-lg shadow p-6">
            <h2 class="text-lg font-semibold mb-4">Optimization Convergence</h2>
            <%= if @convergence_data do %>
              <div class="h-64">
                <svg viewBox="0 0 400 200" class="w-full h-full">
                  <!-- Grid lines -->
                  <g class="text-gray-300">
                    <%= for y <- [0, 50, 100, 150, 200] do %>
                      <line x1="40" y1={y} x2="380" y2={y} stroke="currentColor" stroke-width="0.5" />
                    <% end %>
                  </g>
                  
                  <!-- Data line -->
                  <polyline
                    points={convergence_polyline(@convergence_data)}
                    fill="none"
                    stroke="#3b82f6"
                    stroke-width="2"
                  />
                  
                  <!-- Data points -->
                  <%= for point <- @convergence_data do %>
                    <circle
                      cx={40 + (point.trial - 1) * 340 / max(length(@convergence_data) - 1, 1)}
                      cy={200 - normalize_value(point.best_value, @convergence_data) * 180}
                      r="3"
                      fill="#3b82f6"
                    />
                  <% end %>
                  
                  <!-- Axes -->
                  <line x1="40" y1="200" x2="380" y2="200" stroke="black" stroke-width="1" />
                  <line x1="40" y1="0" x2="40" y2="200" stroke="black" stroke-width="1" />
                  
                  <!-- Labels -->
                  <text x="200" y="230" text-anchor="middle" class="text-xs">Trial Number</text>
                  <text x="20" y="100" text-anchor="middle" transform="rotate(-90 20 100)" class="text-xs">
                    Best Value
                  </text>
                </svg>
              </div>
            <% else %>
              <p class="text-gray-500">Insufficient data for convergence plot</p>
            <% end %>
          </div>
          
          <!-- Parameter Importance -->
          <div class="bg-white rounded-lg shadow p-6">
            <h2 class="text-lg font-semibold mb-4">Parameter Importance</h2>
            <%= if @importance_data do %>
              <div class="space-y-2">
                <%= for param <- Enum.take(@importance_data, 5) do %>
                  <div class="flex items-center justify-between">
                    <span class="text-sm font-medium"><%= param.parameter %></span>
                    <div class="flex items-center space-x-2">
                      <div class="w-32 bg-gray-200 rounded-full h-2">
                        <div 
                          class="bg-blue-600 h-2 rounded-full"
                          style={"width: #{param.importance * 100}%"}
                        ></div>
                      </div>
                      <span class="text-xs text-gray-600">
                        <%= Float.round(param.importance, 3) %>
                      </span>
                    </div>
                  </div>
                <% end %>
              </div>
            <% else %>
              <p class="text-gray-500">Insufficient data for importance analysis</p>
            <% end %>
          </div>
          
          <!-- Optimization Heatmap -->
          <div class="bg-white rounded-lg shadow p-6">
            <h2 class="text-lg font-semibold mb-4">Optimization History Heatmap</h2>
            <%= if @heatmap_data do %>
              <div class="h-32">
                <svg viewBox="0 0 400 100" class="w-full h-full">
                  <%= for bucket <- @heatmap_data.buckets do %>
                    <rect
                      x={40 + bucket.bucket * 340 / length(@heatmap_data.buckets)}
                      y="20"
                      width={340 / length(@heatmap_data.buckets)}
                      height="60"
                      fill={heatmap_color(bucket.mean, @heatmap_data.buckets)}
                      stroke="white"
                      stroke-width="1"
                    />
                  <% end %>
                  
                  <!-- Labels -->
                  <text x="200" y="95" text-anchor="middle" class="text-xs">
                    Trial Buckets (→ time)
                  </text>
                </svg>
              </div>
              <div class="mt-2 flex items-center justify-between text-xs text-gray-600">
                <span>Better ←</span>
                <div class="flex space-x-1">
                  <div class="w-4 h-4 bg-blue-600"></div>
                  <div class="w-4 h-4 bg-blue-400"></div>
                  <div class="w-4 h-4 bg-yellow-400"></div>
                  <div class="w-4 h-4 bg-orange-400"></div>
                  <div class="w-4 h-4 bg-red-400"></div>
                </div>
                <span>→ Worse</span>
              </div>
            <% else %>
              <p class="text-gray-500">Insufficient data for heatmap</p>
            <% end %>
          </div>
          
          <!-- Parallel Coordinates -->
          <div class="bg-white rounded-lg shadow p-6">
            <h2 class="text-lg font-semibold mb-4">Parallel Coordinates</h2>
            <%= if @parallel_coords_data do %>
              <div class="h-64 overflow-x-auto">
                <svg viewBox="0 0 500 200" class="min-w-full h-full">
                  <!-- Vertical axes for each parameter -->
                  <%= for {dim, idx} <- Enum.with_index(@parallel_coords_data.dimensions) do %>
                    <line
                      x1={50 + idx * 100}
                      y1="20"
                      x2={50 + idx * 100}
                      y2="180"
                      stroke="black"
                      stroke-width="1"
                    />
                    <text
                      x={50 + idx * 100}
                      y="195"
                      text-anchor="middle"
                      class="text-xs"
                    >
                      <%= dim %>
                    </text>
                  <% end %>
                  
                  <!-- Data lines -->
                  <%= for trial <- @parallel_coords_data.data do %>
                    <polyline
                      points={parallel_coords_line(trial, @parallel_coords_data.dimensions)}
                      fill="none"
                      stroke={trial.color}
                      stroke-width="1"
                      opacity="0.5"
                    />
                  <% end %>
                </svg>
              </div>
            <% else %>
              <p class="text-gray-500">Insufficient data for parallel coordinates</p>
            <% end %>
          </div>
        </div>
        
        <!-- Stats Summary -->
        <div class="mt-6 bg-white rounded-lg shadow p-6">
          <h2 class="text-lg font-semibold mb-4">Summary Statistics</h2>
          <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
            <div>
              <p class="text-sm text-gray-600">Total Trials</p>
              <p class="text-2xl font-bold"><%= length(@trials) %></p>
            </div>
            <div>
              <p class="text-sm text-gray-600">Completed</p>
              <p class="text-2xl font-bold">
                <%= Enum.count(@trials, &(&1[:status] in [:succeeded, "succeeded"])) %>
              </p>
            </div>
            <div>
              <p class="text-sm text-gray-600">Best Value</p>
              <p class="text-2xl font-bold">
                <%= best_value(@trials) %>
              </p>
            </div>
            <div>
              <p class="text-sm text-gray-600">Parameters</p>
              <p class="text-2xl font-bold">
                <%= param_count(@trials) %>
              </p>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
  
  # Helper functions for rendering
  
  defp convergence_polyline(data) do
    max_trial = length(data)
    
    data
    |> Enum.map(fn point ->
      x = 40 + (point.trial - 1) * 340 / max(max_trial - 1, 1)
      y = 200 - normalize_value(point.best_value, data) * 180
      "#{x},#{y}"
    end)
    |> Enum.join(" ")
  end
  
  defp normalize_value(value, data) do
    values = Enum.map(data, & &1.best_value)
    min_val = Enum.min(values)
    max_val = Enum.max(values)
    
    if max_val == min_val do
      0.5
    else
      (value - min_val) / (max_val - min_val)
    end
  end
  
  defp heatmap_color(mean, buckets) do
    all_means = Enum.map(buckets, & &1.mean)
    min_mean = Enum.min(all_means)
    max_mean = Enum.max(all_means)
    
    if max_mean == min_mean do
      "#3b82f6"
    else
      normalized = (mean - min_mean) / (max_mean - min_mean)
      
      cond do
        normalized < 0.2 -> "#3b82f6"  # Blue
        normalized < 0.4 -> "#60a5fa"  # Light blue
        normalized < 0.6 -> "#fbbf24"  # Yellow
        normalized < 0.8 -> "#fb923c"  # Orange
        true -> "#ef4444"              # Red
      end
    end
  end
  
  defp parallel_coords_line(trial, dimensions) do
    dimensions
    |> Enum.with_index()
    |> Enum.map(fn {dim, idx} ->
      x = 50 + idx * 100
      # Normalize parameter value to 0-1 for y position
      y = 180  # Default position, would need actual normalization
      "#{x},#{y}"
    end)
    |> Enum.join(" ")
  end
  
  defp best_value([]), do: "N/A"
  defp best_value(trials) do
    trials
    |> Enum.filter(&(&1[:status] in [:succeeded, "succeeded"]))
    |> Enum.map(& &1[:value])
    |> case do
      [] -> "N/A"
      values -> values |> Enum.min() |> Float.round(4)
    end
  end
  
  defp param_count([]), do: 0
  defp param_count([trial | _]) do
    trial[:params] |> Map.keys() |> length()
  end
end