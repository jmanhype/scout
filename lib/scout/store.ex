defmodule Scout.Store do
  @moduledoc """
  Facade and behaviour definition for Scout storage backends.
  
  This module defines the storage contract and delegates to the configured
  storage adapter (ETS or Ecto).
  """

  @callback put_study(map()) :: :ok | {:error, term()}
  @callback set_study_status(String.t(), String.t()) :: :ok | {:error, term()}
  @callback get_study(String.t()) :: {:ok, map()} | :error
  @callback add_trial(String.t(), map()) :: {:ok, String.t()} | {:error, term()}
  @callback update_trial(String.t(), map()) :: :ok | {:error, term()}
  @callback record_observation(String.t(), String.t(), non_neg_integer(), non_neg_integer(), number()) :: :ok
  @callback list_trials(String.t(), keyword()) :: [map()]
  @callback fetch_trial(String.t()) :: {:ok, map()} | :error
  @callback observations_at_rung(String.t(), non_neg_integer(), non_neg_integer()) :: [{String.t(), number()}]

  # Get the configured adapter at compile time
  @adapter Application.compile_env(:scout, :store_adapter, Scout.Store.ETS)

  @doc """
  Returns a child specification for the configured storage adapter.
  """
  def child_spec(arg), do: @adapter.child_spec(arg)

  # Facade delegates - no local state in this module
  def put_study(study), do: @adapter.put_study(study)
  def set_study_status(id, status), do: @adapter.set_study_status(id, status)
  def get_study(id), do: @adapter.get_study(id)
  def add_trial(study_id, trial), do: @adapter.add_trial(study_id, trial)
  def update_trial(id, updates), do: @adapter.update_trial(id, updates)
  def record_observation(study_id, trial_id, bracket, rung, score) do
    @adapter.record_observation(study_id, trial_id, bracket, rung, score)
  end
  def list_trials(study_id, filters \\ []), do: @adapter.list_trials(study_id, filters)
  def fetch_trial(id), do: @adapter.fetch_trial(id)
  def observations_at_rung(study_id, bracket, rung) do
    @adapter.observations_at_rung(study_id, bracket, rung)
  end
end