
defmodule ScoutDashboardWeb.HomeLive do
  use ScoutDashboardWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <h1>Scout Live Dashboard</h1>
    <p>Enter a Study ID to monitor:</p>
    <form phx-submit="go">
      <input name="study_id" placeholder="study id"/>
      <button>Open</button>
    </form>
    """
  end

  @impl true
  def handle_event("go", %{"study_id" => id}, socket) do
    {:noreply, push_navigate(socket, to: "/studies/#{id}")}
  end
end
