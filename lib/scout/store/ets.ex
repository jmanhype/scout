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
  
  def add_trial(study_id, trial) do
    GenServer.call(__MODULE__, {:add_trial, study_id, trial})
  end
  
  def update_trial(id, updates) do
    GenServer.call(__MODULE__, {:update_trial, id, updates})
  end
  
  def record_observation(study_id, trial_id, bracket, rung, score) do
    # Use cast for performance since observations are write-heavy
    GenServer.cast(__MODULE__, {:record_observation, study_id, trial_id, bracket, rung, score})
    :ok
  end
  
  @impl Scout.Store.Adapter
  def list_trials(_study_id, _filters \\ []) do
    # TODO: Actually filter by study_id once we store it properly
    :ets.foldl(fn {id, t}, acc -> [Map.put(t, :id, id) | acc] end, [], @trials) 
    |> Enum.reverse()
  end
  
  def fetch_trial(id) do
    case :ets.lookup(@trials, id) do
      [{^id, t}] -> {:ok, Map.put(t, :id, id)}
      _ -> :error
    end
  end
  
  @impl Scout.Store.Adapter
  def observations_at_rung(study_id, bracket, rung) do
    :ets.lookup(@obs, {study_id, bracket, rung})
    |> Enum.map(fn {_key, trial_id, score} -> {trial_id, score} end)
  end

  # Implement missing Scout.Store.Adapter callbacks
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
  def get_trial(_study_id, trial_id) do
    case fetch_trial(trial_id) do
      {:ok, trial} -> {:ok, trial}
      _ -> {:error, :not_found}
    end
  end

  @impl Scout.Store.Adapter
  def put_trial(study_id, trial) do
    add_trial(study_id, trial)
  end

  @impl Scout.Store.Adapter
  def update_trial(_study_id, trial_id, updates) do
    case update_trial(trial_id, updates) do
      :ok -> {:ok, nil}
      error -> error
    end
  end

  @impl Scout.Store.Adapter
  def delete_trial(study_id, trial_id) do
    GenServer.call(__MODULE__, {:delete_trial, study_id, trial_id})
  end

  @impl Scout.Store.Adapter
  def put_observation(study_id, trial_id, observation) do
    score = Map.get(observation, :score) || Map.get(observation, :value)
    bracket = Map.get(observation, :bracket, 0)
    rung = Map.get(observation, :rung, 0)
    record_observation(study_id, trial_id, bracket, rung, score)
    {:ok, observation}
  end

  @impl Scout.Store.Adapter
  def list_observations(study_id, trial_id) do
    pattern = {{study_id, :_, :_}, trial_id, :"$1"}
    :ets.match(@obs, pattern)
    |> List.flatten()
    |> Enum.map(fn score -> %{value: score} end)
  end
  
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
  def handle_call({:add_trial, _study_id, trial}, _from, state) do
    id = Map.get(trial, :id) || Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)
    trial_with_id = Map.put(trial, :id, id)
    :ets.insert(@trials, {id, trial_with_id})
    {:reply, {:ok, id}, state}
  end
  
  @impl GenServer
  def handle_call({:update_trial, id, updates}, _from, state) do
    result = case :ets.lookup(@trials, id) do
      [{^id, t}] -> 
        :ets.insert(@trials, {id, Map.merge(t, updates)})
        :ok
      _ -> 
        {:error, :not_found}
    end
    {:reply, result, state}
  end
  
  @impl GenServer
  def handle_cast({:record_observation, study_id, trial_id, bracket, rung, score}, state) do
    :ets.insert(@obs, {{study_id, bracket, rung}, trial_id, score})
    {:noreply, state}
  end
  
  @impl GenServer
  def handle_cast({:mark_pruned, study_id, trial_id}, state) do
    :ets.insert(@events, {{study_id, :pruned}, trial_id})
    {:noreply, state}
  end

  @impl GenServer
  def handle_call({:delete_study, id}, _from, state) do
    :ets.delete(@studies, id)
    # Delete related trials
    trials_to_delete = :ets.foldl(fn {trial_id, _trial}, acc -> 
      [trial_id | acc]
    end, [], @trials)
    Enum.each(trials_to_delete, &:ets.delete(@trials, &1))
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call({:delete_trial, _study_id, trial_id}, _from, state) do
    :ets.delete(@trials, trial_id)
    {:reply, :ok, state}
  end
end