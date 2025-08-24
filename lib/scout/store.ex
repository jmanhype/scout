defmodule Scout.Store do
  @moduledoc """
  Behaviour definition for Scout storage backends.
  """

  @callback put_study(map()) :: :ok | {:error, term()}
  @callback set_study_status(String.t(), String.t()) :: :ok | {:error, term()}
  @callback get_study(String.t()) :: {:ok, map()} | :error
  @callback add_trial(String.t(), map()) :: {:ok, String.t()} | {:error, term()}
  @callback update_trial(String.t(), map()) :: :ok | {:error, term()}
  @callback record_observation(String.t(), integer(), number()) :: :ok
  @callback list_trials(String.t(), keyword()) :: list(map())
  @callback fetch_trial(String.t()) :: {:ok, map()} | :error

  use GenServer
  alias Scout.Trial

  @studies :scout_studies
  @trials  :scout_trials
  @obs     :scout_obs
  @events  :scout_events

  def start_link(_), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  @impl true
  def init(_) do
    :ets.new(@studies, [:named_table, :public, :set, {:read_concurrency, true}])
    :ets.new(@trials,  [:named_table, :public, :bag, {:write_concurrency, true}])
    :ets.new(@obs,     [:named_table, :public, :bag, {:write_concurrency, true}])
    :ets.new(@events,  [:named_table, :public, :bag, {:write_concurrency, true}])
    {:ok, %{}}
  end

  # studies
  def put_study(map) do
    :ets.insert(@studies, {map.id, map})
    :ok
  end
  def set_study_status(id, status) do
    case :ets.lookup(@studies, id) do
      [{_, study}] -> 
        :ets.insert(@studies, {id, Map.put(study, :status, status)})
        :ok
      _ -> {:error, :not_found}
    end
  end
  def get_study(id) do
    case :ets.lookup(@studies, id) do
      [{_, m}] -> {:ok, m}
      _ -> :error
    end
  end

  # trials
  def add_trial(study_id, %Trial{} = t) do
    :ets.insert(@trials, {study_id, t.id, t})
    {:ok, t}
  end
  def update_trial(trial_id, fields) do
    case find_trial_by_id(trial_id) do
      {:ok, {sid, _id, t}} ->
        t2 = struct(t, fields)
        :ets.insert(@trials, {sid, t2.id, t2})
        {:ok, t2}
      _ -> {:error, :not_found}
    end
  end
  def list_trials(study_id) do
    :ets.lookup(@trials, study_id) |> Enum.map(fn {_sid, _id, t} -> t end)
  end
  def find_trial_by_id(trial_id) do
    :ets.foldl(fn {sid, id, t}, acc ->
      if id == trial_id, do: {:ok, {sid, id, t}}, else: acc
    end, :error, @trials)
  end

  # observations (per study, bracket, rung, trial)
  def record_observation(study_id, trial_id, bracket, rung, score) do
    :ets.insert(@obs, {{study_id, bracket, rung}, trial_id, score})
    :ok
  end
  def observations_at_rung(study_id, bracket, rung) do
    :ets.lookup(@obs, {study_id, bracket, rung})
    |> Enum.map(fn {{_k}, trial_id, score} -> {trial_id, score} end)
  end

  # events (e.g., pruned)
  def mark_pruned(study_id, trial_id) do
    :ets.insert(@events, {{study_id, :pruned}, trial_id})
    :ok
  end
  def pruned?(study_id, trial_id) do
    case :ets.lookup(@events, {study_id, :pruned}) |> Enum.find(fn {_, id} -> id == trial_id end) do
      nil -> false
      _ -> true
    end
  end
end
