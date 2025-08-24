
defmodule ScoutDashboardWeb.DashboardLive do
  use ScoutDashboardWeb, :live_view

  alias ScoutDashboard.ScoutClient

  @tick 1000

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    IO.puts("LiveView mounted for study: #{id}")
    if connected?(socket) do
      IO.puts("Socket connected, starting timer")
      :timer.send_interval(@tick, :tick)
    else
      IO.puts("Socket not connected yet")
    end
    
    # Get initial data
    status = ScoutClient.status(id)
    best = ScoutClient.best(id)
    IO.inspect(best, label: "Initial best result in mount")
    
    {:ok,
      socket
      |> assign(:study_id, id)
      |> assign(:status, status)
      |> assign(:best, best)
      |> assign(:history, [])
    }
  end

  @impl true
  def handle_info(:tick, socket) do
    study_id = socket.assigns.study_id
    status = ScoutClient.status(study_id)
    best = ScoutClient.best(study_id)
    IO.inspect(best, label: "ScoutClient.best returned")
    history = Enum.take([best | socket.assigns.history], 120)
    {:noreply, assign(socket, status: status, best: best, history: history)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <h2>Study: <%= @study_id %></h2>
    <.best_panel best={@best} />
    <.brackets status={@status} />
    <.sparkline history={@history} />
    """
  end

  # Components
  attr :best, :map
  def best_panel(assigns) do
    ~H"""
    <section>
      <h3>Best Score</h3>
      <%= if @best do %>
        <p><strong><%= Float.round(@best.score, 6) %></strong> (trial <%= @best.trial_id %>)</p>
      <% else %>
        <p>No result yet.</p>
      <% end %>
    </section>
    """
  end

  attr :status, :map
  def brackets(assigns) do
    ~H"""
    <section>
      <h3>Hyperband Brackets</h3>
      <%= for {b_ix, rungs} <- @status.brackets do %>
        <article style="margin: 1rem 0; padding: .5rem; border: 1px solid #ddd;">
          <h4>Bracket <%= b_ix %></h4>
          <table>
            <thead>
              <tr><th>Rung</th><th>Running</th><th>Completed</th><th>Pruned</th><th>Observed</th><th>Chart</th></tr>
            </thead>
            <tbody>
            <%= for {r_ix, stats} <- Enum.sort_by(rungs, fn {ix, _} -> ix end) do %>
              <tr>
                <td><%= r_ix %></td>
                <td><%= Map.get(stats, :running, 0) %></td>
                <td><%= Map.get(stats, :completed, 0) %></td>
                <td><%= Map.get(stats, :pruned, 0) %></td>
                <td><%= Map.get(stats, :observed, 0) %></td>
                <td><%= Phoenix.HTML.raw bar_svg(stats) %></td>
              </tr>
            <% end %>
            </tbody>
          </table>
        </article>
      <% end %>
    </section>
    """
  end

  defp bar_svg(stats) do
    total = Enum.max([1, Map.get(stats, :observed, 0)])
    running = Map.get(stats, :running, 0)
    completed = Map.get(stats, :completed, 0)
    pruned = Map.get(stats, :pruned, 0)
    width = 200
    height = 16
    seg = fn x -> round(width * (x / total)) end
    """
    <svg width="#{width}" height="#{height}" xmlns="http://www.w3.org/2000/svg">
      <rect x="0" y="0" width="#{width}" height="#{height}" fill="#eee" />
      <rect x="0" y="0" width="#{seg.(completed)}" height="#{height}" fill="#88cc88" />
      <rect x="#{seg.(completed)}" y="0" width="#{seg.(running)}" height="#{height}" fill="#88aaff" />
      <rect x="#{seg.(completed)+seg.(running)}" y="0" width="#{seg.(pruned)}" height="#{height}" fill="#ff9999" />
    </svg>
    """
  end

  attr :history, :list
  def sparkline(assigns) do
    ~H"""
    <section>
      <h3>Best Score (last <%= length(@history) %> ticks)</h3>
      <%= Phoenix.HTML.raw spark_svg(@history) %>
    </section>
    """
  end

  defp spark_svg([]), do: "<svg width=\"300\" height=\"40\"></svg>"
  defp spark_svg(history) do
    w = 300; h = 40
    scores = Enum.map(history, & &1.score)
    min = Enum.min(scores); max = Enum.max(scores)
    norm = fn s ->
      denom = max - min
      y = if denom == 0, do: h/2, else: h - (s - min) / denom * (h - 6) - 3
      Float.round(y, 2)
    end
    xs = Enum.with_index(scores, fn _s, i -> 3 + i * max(1, div(w-6, max(1, length(scores)-1))) end)
    pts = Enum.zip(xs, Enum.map(scores, norm))
          |> Enum.map(fn {x,y} -> "#{x},#{y}" end)
          |> Enum.join(" ")
    """
    <svg width="#{w}" height="#{h}" xmlns="http://www.w3.org/2000/svg">
      <polyline fill="none" stroke="#333" stroke-width="2" points="#{pts}" />
    </svg>
    """
  end
end
