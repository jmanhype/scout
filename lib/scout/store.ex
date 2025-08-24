defmodule Scout.Store do
  @moduledoc """
  Storage facade with runtime adapter configuration.
  
  Delegates to configured storage adapter while providing interface stability.
  Uses behaviour-based contracts to prevent interface mismatches.
  
  ## Available Adapters
  
  - `Scout.Store.ETS` (default) - In-memory storage, fast but non-persistent
  - `Scout.Store.Postgres` - PostgreSQL storage, persistent and distributed-ready
  
  ## Configuration
  
      # Runtime configuration (preferred)
      config :scout, :store_adapter, Scout.Store.ETS
  """

  alias Scout.StoreBehaviour

  # Runtime adapter configuration (not compile-time locked)
  defp adapter do
    Application.get_env(:scout, :store_adapter, Scout.Store.ETS)
  end

  @doc """
  Returns a child specification for the configured storage adapter.
  """
  @spec child_spec(term()) :: Supervisor.child_spec()
  def child_spec(arg), do: adapter().child_spec(arg)

  # Import types from behaviour
  @type study_id :: StoreBehaviour.study_id()
  @type trial_id :: StoreBehaviour.trial_id()
  @type status :: StoreBehaviour.status()

  # Facade delegates with proper typing
  @spec put_study(map()) :: :ok | {:error, term()}
  def put_study(study), do: adapter().put_study(study)
  
  @spec set_study_status(study_id(), status()) :: :ok | {:error, term()}
  def set_study_status(id, status), do: adapter().set_study_status(id, status)
  
  @spec get_study(study_id()) :: {:ok, map()} | :error
  def get_study(id), do: adapter().get_study(id)
  
  @spec add_trial(study_id(), map()) :: {:ok, trial_id()} | {:error, term()}
  def add_trial(study_id, trial), do: adapter().add_trial(study_id, trial)
  
  @spec update_trial(trial_id(), map()) :: :ok | {:error, term()}
  def update_trial(id, updates), do: adapter().update_trial(id, updates)
  
  @spec record_observation(trial_id(), non_neg_integer(), non_neg_integer(), number()) :: :ok | {:error, term()}
  def record_observation(trial_id, bracket, rung, score) do
    adapter().record_observation(trial_id, bracket, rung, score)
  end
  
  @spec list_trials(study_id(), keyword()) :: [map()]
  def list_trials(study_id, filters \\ []), do: adapter().list_trials(study_id, filters)
  
  @spec fetch_trial(trial_id()) :: {:ok, map()} | :error
  def fetch_trial(id), do: adapter().fetch_trial(id)
  
  @spec observations_at_rung(study_id(), non_neg_integer(), non_neg_integer()) :: [{trial_id(), number()}]
  def observations_at_rung(study_id, bracket, rung) do
    adapter().observations_at_rung(study_id, bracket, rung)
  end

  @spec delete_study(study_id()) :: :ok | {:error, term()}
  def delete_study(study_id), do: adapter().delete_study(study_id)

  @spec health_check() :: :ok | {:error, term()}
  def health_check(), do: adapter().health_check()
end