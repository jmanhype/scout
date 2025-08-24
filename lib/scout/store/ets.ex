
defmodule Scout.Store.ETS do
  @moduledoc "ETS-backed store (ephemeral)."
  @behaviour Scout.Store
  use GenServer

  @studies __MODULE__.Studies
  @trials  __MODULE__.Trials
  @obs     __MODULE__.Obs

  def start_link(_), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  @impl GenServer
  def init(_) do
    :ets.new(@studies, [:named_table, :public, :set, read_concurrency: true, write_concurrency: true])
    :ets.new(@trials,  [:named_table, :public, :set, read_concurrency: true, write_concurrency: true])
    :ets.new(@obs,     [:named_table, :public, :bag, read_concurrency: true, write_concurrency: true])
    {:ok, %{}}
  end

  @impl Scout.Store
  def put_study(%{id: id} = study) do
    :ets.insert(@studies, {id, Map.put_new(study, :status, "running")})
    :ok
  end

  @impl Scout.Store
  def set_study_status(id, status) do
    case :ets.lookup(@studies, id) do
      [{^id, s}] -> :ets.insert(@studies, {id, Map.put(s, :status, status)}); :ok
      _ -> {:error, :not_found}
    end
  end

  @impl Scout.Store
  def get_study(id) do
    case :ets.lookup(@studies, id) do
      [{^id, s}] -> {:ok, s}
      _ -> :error
    end
  end

  @impl Scout.Store
  def add_trial(_study_id, trial) do
    id = Map.get(trial, :id) || Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)
    :ets.insert(@trials, {id, Map.put(trial, :id, id)})
    {:ok, id}
  end

  @impl Scout.Store
  def update_trial(id, updates) do
    case :ets.lookup(@trials, id) do
      [{^id, t}] -> :ets.insert(@trials, {id, Map.merge(t, updates)}); :ok
      _ -> {:error, :not_found}
    end
  end

  @impl Scout.Store
  def record_observation(trial_id, rung, score) do
    :ets.insert(@obs, {trial_id, rung, score}); :ok
  end

  @impl Scout.Store
  def list_trials(_study_id, _filters) do
    :ets.foldl(fn {id, t}, acc -> [Map.put(t, :id, id) | acc] end, [], @trials) |> Enum.reverse()
  end

  @impl Scout.Store
  def fetch_trial(id) do
    case :ets.lookup(@trials, id) do
      [{^id, t}] -> {:ok, Map.put(t, :id, id)}
      _ -> :error
    end
  end
end
