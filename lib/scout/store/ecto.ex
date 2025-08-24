
defmodule Scout.Store.Ecto do
  @moduledoc "Ecto-backed store (durable)."
  @behaviour Scout.Store
  use GenServer
  import Ecto.Query
  alias Scout.Repo

  def start_link(_), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  
  @impl GenServer
  def init(state), do: {:ok, state}

  @impl Scout.Store
  def put_study(%{id: id} = study) do
    meta = Map.drop(study, [:id])
    changes = %{id: id, meta: meta, status: meta[:status] || "running"}
    Repo.insert!(%Scout.Store.Ecto.Study{} |> Scout.Store.Ecto.Study.changeset(changes),
      on_conflict: [set: [meta: meta, updated_at: DateTime.utc_now()]], conflict_target: :id)
    :ok
  end

  @impl Scout.Store
  def set_study_status(id, status) do
    from(s in Scout.Store.Ecto.Study, where: s.id == ^id) |> Repo.update_all(set: [status: status])
    :ok
  end

  @impl Scout.Store
  def get_study(id) do
    case Repo.get(Scout.Store.Ecto.Study, id) do
      nil -> :error
      %Scout.Store.Ecto.Study{meta: meta, status: st} -> {:ok, Map.merge(meta, %{id: id, status: st})}
    end
  end

  @impl Scout.Store
  def add_trial(study_id, trial) do
    rec = Repo.insert!(%Scout.Store.Ecto.Trial{
      study_id: study_id, status: to_string(trial.status || :pending),
      params: trial.params, rung: trial.rung, score: trial.score,
      metrics: trial.metrics, error: trial.error, seed: trial.seed
    })
    {:ok, rec.id}
  end

  @impl Scout.Store
  def update_trial(id, updates) do
    with %Scout.Store.Ecto.Trial{} = t <- Repo.get(Scout.Store.Ecto.Trial, id) do
      changes = %{
        status: updates[:status] && to_string(updates[:status]) || t.status,
        rung: Map.get(updates, :rung, t.rung),
        score: Map.get(updates, :score, t.score),
        metrics: Map.get(updates, :metrics, t.metrics),
        error: Map.get(updates, :error, t.error)
      }
      Repo.update!(Ecto.Changeset.change(t, changes)); :ok
    else
      _ -> {:error, :not_found}
    end
  end

  @impl Scout.Store
  def record_observation(trial_id, rung, score) do
    Repo.insert!(%Scout.Store.Ecto.Observation{trial_id: trial_id, rung: rung, score: score}); :ok
  end

  @impl Scout.Store
  def list_trials(study_id, _filters) do
    Repo.all(from t in Scout.Store.Ecto.Trial, where: t.study_id == ^study_id, order_by: [asc: t.id])
    |> Enum.map(fn t -> %{id: t.id, study: t.study_id, params: t.params, status: String.to_atom(t.status), rung: t.rung, score: t.score, metrics: t.metrics, error: t.error, seed: t.seed} end)
  end

  @impl Scout.Store
  def fetch_trial(id) do
    case Repo.get(Scout.Store.Ecto.Trial, id) do
      nil -> :error
      t -> {:ok, %{id: t.id, study: t.study_id, params: t.params, status: String.to_atom(t.status), rung: t.rung, score: t.score, metrics: t.metrics, error: t.error, seed: t.seed}}
    end
  end

  @impl Scout.Store
  def observations_at_rung(_study_id, _bracket, _rung) do
    # For Ecto, we might need to store bracket info or simplify
    # For now, return empty list as we're using simple record_observation
    []
  end

  @impl Scout.Store
  def record_observation(_study_id, trial_id, _bracket, rung, score) do
    # Simplified version that ignores study_id and bracket
    record_observation(trial_id, rung, score)
  end
end
