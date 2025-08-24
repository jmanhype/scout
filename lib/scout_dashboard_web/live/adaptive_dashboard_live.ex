defmodule ScoutDashboardWeb.AdaptiveDashboardLive do
  @moduledoc """
  Enhanced dashboard with adaptive update intervals.
  
  Adjusts polling frequency based on trial activity:
  - Active trials: 500ms updates
  - Recent activity: 1s updates
  - Low activity: 2s updates
  - Idle: 5s updates
  """
  use ScoutDashboardWeb, :live_view

  alias ScoutDashboard.ScoutClient

  # Update intervals in milliseconds
  @fast_tick 500      # During active optimization
  @normal_tick 1000   # Recent activity
  @slow_tick 2000     # Low activity
  @idle_tick 5000     # No recent changes
  
  # Activity thresholds
  @high_activity_threshold 5    # Trials in last update
  @medium_activity_threshold 1  # Trials in last update
  @idle_threshold 10            # Seconds without changes

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    IO.puts("Adaptive LiveView mounted for study: #{id}")
    
    if connected?(socket) do
      IO.puts("Socket connected, starting adaptive timer")
      # Start with normal interval
      Process.send_after(self(), :tick, @normal_tick)
    end
    
    # Get initial data
    status = ScoutClient.status(id)
    best = ScoutClient.best(id)
    
    {:ok,
      socket
      |> assign(:study_id, id)
      |> assign(:status, status)
      |> assign(:best, best)
      |> assign(:history, [])
      |> assign(:current_interval, @normal_tick)
      |> assign(:last_trial_count, count_trials(status))
      |> assign(:last_best_score, best && best.score)
      |> assign(:idle_count, 0)
      |> assign(:activity_level, :normal)
    }
  end

  @impl true
  def handle_info(:tick, socket) do
    study_id = socket.assigns.study_id
    
    # Fetch new data
    status = ScoutClient.status(study_id)
    best = ScoutClient.best(study_id)
    
    # Calculate activity level
    current_trial_count = count_trials(status)
    trials_delta = current_trial_count - socket.assigns.last_trial_count
    score_changed = best && best.score != socket.assigns.last_best_score
    
    # Determine new interval and activity level
    {new_interval, activity_level, idle_count} = 
      calculate_interval(trials_delta, score_changed, socket.assigns.idle_count)
    
    # Update history
    history = if best do
      Enum.take([best | socket.assigns.history], 120)
    else
      socket.assigns.history
    end
    
    # Schedule next tick with adaptive interval
    Process.send_after(self(), :tick, new_interval)
    
    {:noreply,
      socket
      |> assign(:status, status)
      |> assign(:best, best)
      |> assign(:history, history)
      |> assign(:current_interval, new_interval)
      |> assign(:last_trial_count, current_trial_count)
      |> assign(:last_best_score, best && best.score)
      |> assign(:idle_count, idle_count)
      |> assign(:activity_level, activity_level)
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="adaptive-dashboard">
      <div class="dashboard-header">
        <h2>Study: <%= @study_id %></h2>
        <.activity_indicator 
          activity_level={@activity_level} 
          interval={@current_interval} 
        />
      </div>
      
      <.best_panel best={@best} />
      <.progress_summary status={@status} />
      <.brackets status={@status} />
      <.sparkline history={@history} />
    </div>
    """
  end

  # Components
  
  attr :activity_level, :atom
  attr :interval, :integer
  def activity_indicator(assigns) do
    ~H"""
    <div class="activity-indicator">
      <span class={"activity-dot activity-#{@activity_level}"}>●</span>
      <span class="activity-text">
        <%= format_activity_level(@activity_level) %> 
        (updates every <%= format_interval(@interval) %>)
      </span>
    </div>
    <style>
      .activity-indicator {
        display: inline-flex;
        align-items: center;
        gap: 0.5rem;
        padding: 0.25rem 0.5rem;
        background: #f5f5f5;
        border-radius: 4px;
      }
      .activity-dot {
        font-size: 1.2rem;
        animation: pulse 2s infinite;
      }
      .activity-high { color: #22c55e; animation-duration: 0.5s; }
      .activity-normal { color: #3b82f6; animation-duration: 1s; }
      .activity-low { color: #f59e0b; animation-duration: 2s; }
      .activity-idle { color: #9ca3af; animation-duration: 5s; }
      @keyframes pulse {
        0%, 100% { opacity: 1; }
        50% { opacity: 0.5; }
      }
    </style>
    """
  end
  
  attr :best, :map
  def best_panel(assigns) do
    ~H"""
    <section class="best-panel">
      <h3>Best Score</h3>
      <%= if @best do %>
        <div class="best-value">
          <strong><%= Float.round(@best.score, 6) %></strong>
          <span class="best-trial">(trial <%= @best.trial_id %>)</span>
        </div>
      <% else %>
        <p class="no-result">No result yet.</p>
      <% end %>
    </section>
    """
  end
  
  attr :status, :map
  def progress_summary(assigns) do
    ~H"""
    <section class="progress-summary">
      <h3>Progress Summary</h3>
      <div class="progress-stats">
        <div class="stat">
          <span class="stat-label">Total Trials:</span>
          <span class="stat-value"><%= count_trials(@status) %></span>
        </div>
        <div class="stat">
          <span class="stat-label">Active Brackets:</span>
          <span class="stat-value"><%= count_active_brackets(@status) %></span>
        </div>
        <div class="stat">
          <span class="stat-label">Completion:</span>
          <span class="stat-value"><%= calculate_completion(@status) %>%</span>
        </div>
      </div>
    </section>
    <style>
      .progress-stats {
        display: flex;
        gap: 2rem;
        padding: 1rem;
        background: #f9f9f9;
        border-radius: 4px;
      }
      .stat {
        display: flex;
        flex-direction: column;
      }
      .stat-label {
        font-size: 0.875rem;
        color: #666;
      }
      .stat-value {
        font-size: 1.5rem;
        font-weight: bold;
        color: #333;
      }
    </style>
    """
  end

  attr :status, :map
  def brackets(assigns) do
    ~H"""
    <section>
      <h3>Hyperband Brackets</h3>
      <%= for {b_ix, rungs} <- @status.brackets do %>
        <article class="bracket">
          <h4>Bracket <%= b_ix %></h4>
          <table>
            <thead>
              <tr>
                <th>Rung</th>
                <th>Running</th>
                <th>Completed</th>
                <th>Pruned</th>
                <th>Total</th>
                <th>Progress</th>
              </tr>
            </thead>
            <tbody>
            <%= for {r_ix, stats} <- Enum.sort_by(rungs, fn {ix, _} -> ix end) do %>
              <tr>
                <td><%= r_ix %></td>
                <td class="running"><%= Map.get(stats, :running, 0) %></td>
                <td class="completed"><%= Map.get(stats, :completed, 0) %></td>
                <td class="pruned"><%= Map.get(stats, :pruned, 0) %></td>
                <td><%= Map.get(stats, :observed, 0) %></td>
                <td><%= Phoenix.HTML.raw bar_svg(stats) %></td>
              </tr>
            <% end %>
            </tbody>
          </table>
        </article>
      <% end %>
    </section>
    <style>
      .bracket {
        margin: 1rem 0;
        padding: 1rem;
        border: 1px solid #ddd;
        border-radius: 4px;
      }
      .bracket table {
        width: 100%;
        border-collapse: collapse;
      }
      .bracket th, .bracket td {
        padding: 0.5rem;
        text-align: left;
      }
      .bracket th {
        background: #f5f5f5;
        font-weight: 600;
      }
      .running { color: #3b82f6; }
      .completed { color: #22c55e; }
      .pruned { color: #ef4444; }
    </style>
    """
  end

  attr :history, :list
  def sparkline(assigns) do
    ~H"""
    <section>
      <h3>Best Score Trend (last <%= length(@history) %> updates)</h3>
      <%= if length(@history) > 1 do %>
        <%= Phoenix.HTML.raw spark_svg(@history) %>
      <% else %>
        <p>Waiting for data...</p>
      <% end %>
    </section>
    """
  end

  # Private functions
  
  defp calculate_interval(trials_delta, score_changed, idle_count) do
    cond do
      trials_delta >= @high_activity_threshold ->
        {@fast_tick, :high, 0}
        
      trials_delta >= @medium_activity_threshold || score_changed ->
        {@normal_tick, :normal, 0}
        
      idle_count >= @idle_threshold ->
        {@idle_tick, :idle, idle_count + 1}
        
      true ->
        {@slow_tick, :low, idle_count + 1}
    end
  end
  
  defp count_trials(%{brackets: brackets}) do
    Enum.reduce(brackets, 0, fn {_b_ix, rungs}, acc ->
      Enum.reduce(rungs, acc, fn {_r_ix, stats}, inner_acc ->
        inner_acc + Map.get(stats, :observed, 0)
      end)
    end)
  end
  defp count_trials(_), do: 0
  
  defp count_active_brackets(%{brackets: brackets}) do
    Enum.count(brackets, fn {_b_ix, rungs} ->
      Enum.any?(rungs, fn {_r_ix, stats} ->
        Map.get(stats, :running, 0) > 0
      end)
    end)
  end
  defp count_active_brackets(_), do: 0
  
  defp calculate_completion(%{brackets: brackets}) do
    {completed, total} = Enum.reduce(brackets, {0, 0}, fn {_b_ix, rungs}, {c, t} ->
      Enum.reduce(rungs, {c, t}, fn {_r_ix, stats}, {c_acc, t_acc} ->
        {
          c_acc + Map.get(stats, :completed, 0) + Map.get(stats, :pruned, 0),
          t_acc + Map.get(stats, :observed, 0)
        }
      end)
    end)
    
    if total > 0 do
      round(completed / total * 100)
    else
      0
    end
  end
  defp calculate_completion(_), do: 0
  
  defp format_activity_level(:high), do: "High Activity"
  defp format_activity_level(:normal), do: "Normal Activity"
  defp format_activity_level(:low), do: "Low Activity"
  defp format_activity_level(:idle), do: "Idle"
  
  defp format_interval(ms) when ms < 1000, do: "#{ms}ms"
  defp format_interval(ms), do: "#{div(ms, 1000)}s"
  
  defp bar_svg(stats) do
    total = Enum.max([1, Map.get(stats, :observed, 0)])
    running = Map.get(stats, :running, 0)
    completed = Map.get(stats, :completed, 0)
    pruned = Map.get(stats, :pruned, 0)
    width = 200
    height = 20
    seg = fn x -> round(width * (x / total)) end
    
    """
    <svg width="#{width}" height="#{height}" xmlns="http://www.w3.org/2000/svg">
      <rect x="0" y="0" width="#{width}" height="#{height}" fill="#f5f5f5" rx="2" />
      <rect x="0" y="0" width="#{seg.(completed)}" height="#{height}" fill="#22c55e" rx="2" />
      <rect x="#{seg.(completed)}" y="0" width="#{seg.(running)}" height="#{height}" fill="#3b82f6" />
      <rect x="#{seg.(completed)+seg.(running)}" y="0" width="#{seg.(pruned)}" height="#{height}" fill="#ef4444" />
    </svg>
    """
  end
  
  defp spark_svg([]), do: "<svg width=\"400\" height=\"60\"></svg>"
  defp spark_svg(history) do
    w = 400
    h = 60
    scores = Enum.map(history, & &1.score)
    min = Enum.min(scores)
    max = Enum.max(scores)
    
    norm = fn s ->
      denom = max - min
      y = if denom == 0, do: h/2, else: h - (s - min) / denom * (h - 10) - 5
      Float.round(y, 2)
    end
    
    xs = Enum.with_index(scores, fn _s, i -> 
      5 + i * max(1, div(w-10, max(1, length(scores)-1))) 
    end)
    
    pts = Enum.zip(xs, Enum.map(scores, norm))
          |> Enum.map(fn {x,y} -> "#{x},#{y}" end)
          |> Enum.join(" ")
    
    """
    <svg width="#{w}" height="#{h}" xmlns="http://www.w3.org/2000/svg">
      <rect width="#{w}" height="#{h}" fill="#fafafa" rx="4" />
      <polyline fill="none" stroke="#3b82f6" stroke-width="2" points="#{pts}" />
      #{Enum.zip(xs, Enum.map(scores, norm))
        |> Enum.map(fn {x,y} -> 
          "<circle cx=\"#{x}\" cy=\"#{y}\" r=\"3\" fill=\"#3b82f6\" />" 
        end)
        |> Enum.join("\n")}
    </svg>
    """
  end
end