defmodule Scout.Store.ETS do
  @moduledoc """
  ETS-based storage adapter for Scout (ephemeral).
  
  Uses protected ETS tables to ensure data integrity while allowing
  read concurrency. All mutations go through the GenServer API.
  """
  
  @behaviour Scout.Store.Adapter
  
  use GenServer
  
  @studies __MODULE__.Studies
  @trials  __MODULE__.Trials
  @obs     __MODULE__.Obs
  @events  __MODULE__.Events
  
  def child_spec(arg) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [arg]}
    }
  end
  
  def start_link(_), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  
  @impl GenServer
  def init(_) do
    # Use :protected instead of :public to prevent external writes
    :ets.new(@studies, [:named_table, :protected, :set, read_concurrency: true])
    :ets.new(@trials,  [:named_table, :protected, :set, read_concurrency: true])
    :ets.new(@obs,     [:named_table, :protected, :bag, read_concurrency: true])
    :ets.new(@events,  [:named_table, :protected, :bag, read_concurrency: true])
    {:ok, %{}}
  end
  
  # Store behaviour implementation - reads can be direct
  
  @impl Scout.Store.Adapter
  def put_study(%{id: id} = study) do
    GenServer.call(__MODULE__, {:put_study, id, study})
  end
  
  @impl Scout.Store.Adapter
  def set_study_status(id, status) do
    GenServer.call(__MODULE__, {:set_study_status, id, status})
  end
  
  @impl Scout.Store.Adapter
  def get_study(id) do
    case :ets.lookup(@studies, id) do
      [{^id, s}] -> {:ok, s}
      _ -> :error
    end
  end
  
  @impl Scout.Store.Adapter
  def add_trial(study_id, trial) do
    GenServer.call(__MODULE__, {:add_trial, study_id, trial})
  end
  
  @impl Scout.Store.Adapter 
  def update_trial(study_id, trial_id, updates) do
    GenServer.call(__MODULE__, {:update_trial, study_id, trial_id, updates})
  end
  
  @impl Scout.Store.Adapter
  def record_observation(study_id, trial_id, bracket, rung, score) do
    # FIXED: Use call instead of cast to ensure writes are acknowledged
    # Performance: Can batch observations if needed, but never lose data
    GenServer.call(__MODULE__, {:record_observation, study_id, trial_id, bracket, rung, score})
  end
  
  @impl Scout.Store.Adapter
  def list_trials(study_id, _filters \\ []) do
    # FIXED: Actually filter by study_id and populate intermediate_values
    :ets.foldl(fn {{sid, tid}, t}, acc ->
      if sid == study_id do
        # Populate intermediate_values from observations
        intermediate_values = get_intermediate_values_for_trial(study_id, tid)
        trial = t
        |> Map.put(:id, tid)
        |> Map.put(:intermediate_values, intermediate_values)
        [trial | acc]
      else
        acc
      end
    end, [], @trials)
    |> Enum.reverse()
  end

  defp get_intermediate_values_for_trial(study_id, trial_id) do
    # Collect all observations for this trial across all brackets and rungs
    :ets.foldl(fn
      {{^study_id, _bracket, rung}, ^trial_id, score}, acc ->
        Map.put(acc, rung, score)
      _, acc ->
        acc
    end, %{}, @obs)
  end
  
  @impl Scout.Store.Adapter
  def fetch_trial(study_id, trial_id) do
    # FIXED: Key by {study_id, trial_id} to match DB uniqueness
    case :ets.lookup(@trials, {study_id, trial_id}) do
      [{{^study_id, ^trial_id}, t}] -> {:ok, Map.put(t, :id, trial_id)}
      _ -> :error
    end
  end
  
  @impl Scout.Store.Adapter
  def observations_at_rung(study_id, bracket, rung) do
    :ets.lookup(@obs, {study_id, bracket, rung})
    |> Enum.map(fn {_key, trial_id, score} -> {trial_id, score} end)
  end

  @impl Scout.Store.Adapter  
  def list_studies do
    :ets.foldl(fn {_id, study}, acc -> [study | acc] end, [], @studies)
    |> Enum.reverse()
  end

  @impl Scout.Store.Adapter
  def delete_study(id) do
    GenServer.call(__MODULE__, {:delete_study, id})
  end

  @impl Scout.Store.Adapter
  def delete_trial(study_id, trial_id) do
    GenServer.call(__MODULE__, {:delete_trial, study_id, trial_id})
  end

  @impl Scout.Store.Adapter
  def health_check(), do: :ok
  
  # Additional public functions for events
  def mark_pruned(study_id, trial_id) do
    GenServer.cast(__MODULE__, {:mark_pruned, study_id, trial_id})
  end
  
  def pruned?(study_id, trial_id) do
    case :ets.lookup(@events, {study_id, :pruned}) 
         |> Enum.find(fn {_key, tid} -> tid == trial_id end) do
      nil -> false
      _ -> true
    end
  end
  
  # GenServer callbacks for mutations
  
  @impl GenServer
  def handle_call({:put_study, id, study}, _from, state) do
    study_with_status = Map.put_new(study, :status, "running")
    :ets.insert(@studies, {id, study_with_status})
    {:reply, :ok, state}
  end
  
  @impl GenServer
  def handle_call({:set_study_status, id, status}, _from, state) do
    result = case :ets.lookup(@studies, id) do
      [{^id, s}] -> 
        :ets.insert(@studies, {id, Map.put(s, :status, status)})
        :ok
      _ -> 
        {:error, :not_found}
    end
    {:reply, result, state}
  end
  
  @impl GenServer
  def handle_call({:add_trial, study_id, trial}, _from, state) do
    trial_id = Map.get(trial, :id) || Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)
    trial_with_id = Map.put(trial, :id, trial_id)
    # FIXED: Key trials by {study_id, trial_id} to prevent cross-study contamination
    :ets.insert(@trials, {{study_id, trial_id}, trial_with_id})
    {:reply, {:ok, trial_id}, state}
  end
  
  @impl GenServer
  def handle_call({:update_trial, study_id, trial_id, updates}, _from, state) do
    key = {study_id, trial_id}
    result = case :ets.lookup(@trials, key) do
      [{^key, t}] -> 
        :ets.insert(@trials, {key, Map.merge(t, updates)})
        :ok
      _ -> 
        {:error, :not_found}
    end
    {:reply, result, state}
  end
  
  @impl GenServer
  def handle_call({:record_observation, study_id, trial_id, bracket, rung, score}, _from, state) do
    :ets.insert(@obs, {{study_id, bracket, rung}, trial_id, score})
    {:reply, :ok, state}
  end
  
  @impl GenServer
  def handle_cast({:mark_pruned, study_id, trial_id}, state) do
    :ets.insert(@events, {{study_id, :pruned}, trial_id})
    {:noreply, state}
  end

  @impl GenServer
  def handle_call({:delete_study, study_id}, _from, state) do
    :ets.delete(@studies, study_id)
    # FIXED: Only delete trials for THIS study (was deleting ALL trials!)
    trials_to_delete = :ets.foldl(fn {{sid, tid}, _trial}, acc -> 
      if sid == study_id do
        [{sid, tid} | acc]  # Collect keys for this study only
      else
        acc
      end
    end, [], @trials)
    Enum.each(trials_to_delete, &:ets.delete(@trials, &1))
    # Also delete related observations and events for this study
    :ets.match_delete(@obs, {{study_id, :_, :_}, :_, :_})
    :ets.match_delete(@events, {{study_id, :_}, :_})
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call({:delete_trial, study_id, trial_id}, _from, state) do
    # FIXED: Use composite key
    :ets.delete(@trials, {study_id, trial_id})
    {:reply, :ok, state}
  end
end