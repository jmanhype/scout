
defmodule ScoutDashboardWeb.HomeLive do
  use ScoutDashboardWeb, :live_view

  @refresh_interval 5000  # Refresh study list every 5 seconds

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: :timer.send_interval(@refresh_interval, :refresh)
    {:ok, assign(socket, studies: fetch_studies())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section>
      <h1>Scout Live Dashboard</h1>
      <p class="text-gray-600 mb-6">Monitor your hyperparameter optimization studies in real-time</p>

      <%= if @studies == [] do %>
        <div class="bg-blue-50 border border-blue-200 rounded-lg p-6 mb-6">
          <h2 class="text-xl font-semibold text-blue-900 mb-2">No Active Studies</h2>
          <p class="text-blue-700 mb-4">
            No optimization studies found. Start a new optimization to see it appear here.
          </p>
          <p class="text-sm text-blue-600">
            Example: <code class="bg-blue-100 px-2 py-1 rounded">mix run examples/optimize.exs</code>
          </p>
        </div>
      <% else %>
        <div class="bg-white shadow overflow-hidden rounded-lg mb-6">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-gray-50">
              <tr>
                <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Study ID
                </th>
                <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Goal
                </th>
                <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Trials
                </th>
                <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Status
                </th>
                <th scope="col" class="relative px-6 py-3">
                  <span class="sr-only">Actions</span>
                </th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              <%= for study <- @studies do %>
                <tr class="hover:bg-gray-50 cursor-pointer" phx-click="view_study" phx-value-id={study.id}>
                  <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                    <%= study.id %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-purple-100 text-purple-800">
                      <%= study.goal || "minimize" %>
                    </span>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    <%= Map.get(study, :max_trials, "∞") %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap">
                    <span class={"inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{status_class(study)}"}>
                      <%= format_status(study) %>
                    </span>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                    <button
                      phx-click="view_study"
                      phx-value-id={study.id}
                      class="text-blue-600 hover:text-blue-900"
                    >
                      View →
                    </button>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      <% end %>

      <details class="bg-gray-50 border border-gray-200 rounded-lg p-4">
        <summary class="cursor-pointer text-sm font-medium text-gray-700">
          Or enter a Study ID manually
        </summary>
        <form phx-submit="go" class="mt-4 flex gap-2">
          <input
            name="id"
            placeholder="study_1234567890"
            class="flex-1"
          />
          <button type="submit">
            Open
          </button>
        </form>
      </details>
    </section>
    """
  end

  @impl true
  def handle_event("go", %{"id" => id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/studies/#{id}")}
  end

  @impl true
  def handle_event("view_study", %{"id" => id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/studies/#{id}")}
  end

  @impl true
  def handle_info(:refresh, socket) do
    {:noreply, assign(socket, studies: fetch_studies())}
  end

  # Private helpers

  defp fetch_studies do
    try do
      studies = Scout.Store.list_studies()

      studies
      |> Enum.sort_by(fn study ->
        # Sort by created_at if available, otherwise by ID (timestamp-based)
        Map.get(study, :created_at, study.id)
      end, :desc)
      |> Enum.take(50)  # Limit to 50 most recent studies
    rescue
      _ -> []
    end
  end

  defp status_class(study) do
    status = Map.get(study, :status)

    # Handle both atoms and strings
    status_normalized = try do
      case status do
        s when is_atom(s) -> s
        s when is_binary(s) -> String.to_existing_atom(s)
        _ -> :unknown
      end
    rescue
      ArgumentError -> :unknown
    end

    case status_normalized do
      :running -> "bg-green-100 text-green-800"
      :completed -> "bg-gray-100 text-gray-800"
      :failed -> "bg-red-100 text-red-800"
      :paused -> "bg-yellow-100 text-yellow-800"
      _ -> "bg-blue-100 text-blue-800"
    end
  end

  defp format_status(study) do
    status = Map.get(study, :status, :unknown)

    status_str = case status do
      s when is_atom(s) -> Atom.to_string(s)
      s when is_binary(s) -> s
      _ -> "unknown"
    end

    String.capitalize(status_str)
  end
end
