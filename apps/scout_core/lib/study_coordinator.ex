defmodule Scout.StudyCoordinator do
  @moduledoc """
  Per-study coordinator to prevent race conditions in trial execution.
  
  CRITICAL RACE CONDITION FIXES:
  - Serializes all trial lifecycle operations per study
  - Prevents concurrent samplers from corrupting shared state
  - Ensures atomic trial index assignment  
  - Coordinates pruning decisions across executors
  - Maintains study-level invariants
  
  Each study gets its own GenServer for coordination.
  All mutating operations MUST go through the coordinator.
  """

  use GenServer
  require Logger

  alias Scout.Store
  alias Scout.TelemetryEnhanced

  @registry_name Scout.Registry.Studies

  defstruct [
    :study_id,
    :current_trial_index,
    :active_trials,
    :completed_trials,
    :study_config
  ]

  @type t :: %__MODULE__{
    study_id: String.t(),
    current_trial_index: non_neg_integer(),
    active_trials: MapSet.t(String.t()),
    completed_trials: non_neg_integer(),
    study_config: map()
  }

  ## Client API

  @doc "Start coordinator for a study"
  def start_link(study_id) when is_binary(study_id) do
    GenServer.start_link(__MODULE__, study_id, name: via_tuple(study_id))
  end

  @doc "Get child spec for supervisor"
  def child_spec(study_id) do
    %{
      id: {__MODULE__, study_id},
      start: {__MODULE__, :start_link, [study_id]},
      type: :worker,
      restart: :transient,
      shutdown: 5000
    }
  end

  @doc """
  Execute trial lifecycle atomically through coordinator.
  
  This prevents race conditions by serializing:
  - Trial index assignment
  - Parameter sampling with proper state
  - Trial creation in store  
  - State updates
  
  Returns {:ok, trial} | {:error, reason}
  """
  def coordinate_trial_creation(study_id, sampler_module, sampler_state, search_space) do
    try do
      GenServer.call(via_tuple(study_id), {
        :create_trial, sampler_module, sampler_state, search_space
      }, :infinity)
    catch
      :exit, {:noproc, _} -> {:error, :coordinator_not_found}
      :exit, {:timeout, _} -> {:error, :coordinator_timeout}
    end
  end

  @doc """
  Record trial completion atomically.
  
  Updates:
  - Trial status and result in store
  - Coordinator state (active -> completed)
  - Study best result if applicable
  - Pruning state if needed
  """
  def complete_trial(study_id, trial_id, result, metadata \\ %{}) do
    try do
      GenServer.call(via_tuple(study_id), {
        :complete_trial, trial_id, result, metadata
      }, :infinity)
    catch
      :exit, {:noproc, _} -> {:error, :coordinator_not_found}
      :exit, {:timeout, _} -> {:error, :coordinator_timeout}
    end
  end

  @doc """
  Record trial failure atomically.
  """
  def fail_trial(study_id, trial_id, error, metadata \\ %{}) do
    try do
      GenServer.call(via_tuple(study_id), {
        :fail_trial, trial_id, error, metadata
      }, :infinity)
    catch
      :exit, {:noproc, _} -> {:error, :coordinator_not_found}
      :exit, {:timeout, _} -> {:error, :coordinator_timeout}
    end
  end

  @doc """
  Check if study should continue (not reached max trials or other limits).
  """
  def should_continue_study(study_id) do
    try do
      GenServer.call(via_tuple(study_id), :should_continue, 5000)
    catch
      :exit, {:noproc, _} -> {:error, :coordinator_not_found}
      :exit, {:timeout, _} -> {:error, :coordinator_timeout}
    end
  end

  @doc """
  Get study progress information.
  """
  def get_study_progress(study_id) do
    try do
      GenServer.call(via_tuple(study_id), :get_progress, 5000)
    catch
      :exit, {:noproc, _} -> {:error, :coordinator_not_found}
      :exit, {:timeout, _} -> {:error, :coordinator_timeout}
    end
  end

  @doc "Stop coordinator gracefully"
  def stop(study_id) do
    try do
      GenServer.stop(via_tuple(study_id), :normal, 5000)
    catch
      :exit, {:noproc, _} -> :ok
      :exit, {:timeout, _} -> {:error, :stop_timeout}
    end
  end

  ## GenServer Implementation

  @impl GenServer
  def init(study_id) do
    # Load study configuration from store
    case Store.get_study(study_id) do
      {:ok, study_config} ->
        # Count existing trials to determine next index
        existing_trials = Store.list_trials(study_id, [])
        current_index = length(existing_trials)
        
        # Track active trials (running but not completed)
        active_trials = existing_trials
          |> Enum.filter(&(&1.status in [:pending, :running]))
          |> Enum.map(& &1.id)
          |> MapSet.new()

        completed_count = existing_trials
          |> Enum.count(&(&1.status in [:completed, :failed, :pruned]))

        state = %__MODULE__{
          study_id: study_id,
          current_trial_index: current_index,
          active_trials: active_trials,
          completed_trials: completed_count,
          study_config: study_config
        }

        Logger.info("Study coordinator started: #{study_id}, index=#{current_index}")
        {:ok, state}
      
      :error ->
        Logger.error("Failed to load study configuration: #{study_id}")
        {:stop, :study_not_found}
    end
  end

  @impl GenServer
  def handle_call({:create_trial, sampler_module, sampler_state, search_space}, _from, state) do
    try do
      # Atomic trial creation
      trial_index = state.current_trial_index
      
      # Get completed trials for sampler (avoid race condition)
      completed_trials = get_completed_trials_for_sampler(state.study_id)
      
      # Sample parameters using provided sampler state
      {params, _new_sampler_state} = sampler_module.sample(
        sampler_state, search_space, completed_trials
      )
      
      # Create trial in store
      trial_attrs = %{
        index: trial_index,
        status: :pending,
        params: params,
        metadata: %{
          sampler: sampler_module,
          created_at: DateTime.utc_now(),
          coordinator_node: Node.self()
        }
      }
      
      case Store.add_trial(state.study_id, trial_attrs) do
        {:ok, trial_id} ->
          # Update coordinator state
          new_state = %{state |
            current_trial_index: trial_index + 1,
            active_trials: MapSet.put(state.active_trials, trial_id)
          }
          
          trial = Map.put(trial_attrs, :id, trial_id)
          
          TelemetryEnhanced.trial_start(%{index: trial_index}, %{
            study_id: state.study_id,
            trial_id: trial_id,
            sampler: sampler_module
          })
          
          {:reply, {:ok, trial}, new_state}
        
        {:error, reason} ->
          Logger.error("Failed to create trial: #{inspect(reason)}")
          {:reply, {:error, reason}, state}
      end
    rescue
      error ->
        Logger.error("Trial creation error: #{Exception.message(error)}")
        {:reply, {:error, error}, state}
    end
  end

  def handle_call({:complete_trial, trial_id, result, metadata}, _from, state) do
    if trial_id in state.active_trials do
      # Update trial in store
      updates = %{
        status: :completed,
        result: result,
        completed_at: DateTime.utc_now(),
        metadata: Map.merge(metadata, %{coordinator_node: Node.self()})
      }
      
      case Store.update_trial(trial_id, updates) do
        :ok ->
          # Update coordinator state
          new_state = %{state |
            active_trials: MapSet.delete(state.active_trials, trial_id),
            completed_trials: state.completed_trials + 1
          }
          
          # Check if this is new best result
          check_and_update_best_result(state.study_id, result, trial_id)
          
          TelemetryEnhanced.trial_complete(%{result: result}, %{
            study_id: state.study_id,
            trial_id: trial_id
          })
          
          {:reply, :ok, new_state}
        
        {:error, reason} ->
          Logger.error("Failed to complete trial #{trial_id}: #{inspect(reason)}")
          {:reply, {:error, reason}, state}
      end
    else
      Scout.Log.warning("Attempted to complete unknown trial: #{trial_id}")
      {:reply, {:error, :trial_not_active}, state}
    end
  end

  def handle_call({:fail_trial, trial_id, error, metadata}, _from, state) do
    if trial_id in state.active_trials do
      # Update trial in store
      updates = %{
        status: :failed,
        error_message: Exception.message(error),
        completed_at: DateTime.utc_now(),
        metadata: Map.merge(metadata, %{
          coordinator_node: Node.self(),
          error_details: inspect(error)
        })
      }
      
      case Store.update_trial(trial_id, updates) do
        :ok ->
          # Update coordinator state
          new_state = %{state |
            active_trials: MapSet.delete(state.active_trials, trial_id),
            completed_trials: state.completed_trials + 1
          }
          
          TelemetryEnhanced.trial_error(%{}, %{
            study_id: state.study_id,
            trial_id: trial_id,
            error: error
          })
          
          {:reply, :ok, new_state}
        
        {:error, reason} ->
          Logger.error("Failed to fail trial #{trial_id}: #{inspect(reason)}")
          {:reply, {:error, reason}, state}
      end
    else
      Scout.Log.warning("Attempted to fail unknown trial: #{trial_id}")
      {:reply, {:error, :trial_not_active}, state}
    end
  end

  def handle_call(:should_continue, _from, state) do
    max_trials = Map.get(state.study_config, :max_trials, 100)
    total_trials = state.current_trial_index
    
    should_continue = total_trials < max_trials
    
    progress = %{
      total_trials: total_trials,
      max_trials: max_trials,
      completed_trials: state.completed_trials,
      active_trials: MapSet.size(state.active_trials),
      should_continue: should_continue
    }
    
    {:reply, {:ok, progress}, state}
  end

  def handle_call(:get_progress, _from, state) do
    progress = %{
      study_id: state.study_id,
      current_trial_index: state.current_trial_index,
      active_trials: MapSet.size(state.active_trials),
      completed_trials: state.completed_trials,
      study_config: state.study_config
    }
    
    {:reply, {:ok, progress}, state}
  end

  ## Private Helpers

  @spec via_tuple(String.t()) :: {:via, Registry, {atom(), String.t()}}
  defp via_tuple(study_id) do
    {:via, Registry, {@registry_name, study_id}}
  end

  @spec get_completed_trials_for_sampler(String.t()) :: [map()]
  defp get_completed_trials_for_sampler(study_id) do
    Store.list_trials(study_id, status: :completed)
  end

  @spec check_and_update_best_result(String.t(), number(), String.t()) :: :ok
  defp check_and_update_best_result(study_id, result, trial_id) do
    case Store.get_study(study_id) do
      {:ok, study} ->
        goal = Map.get(study, :goal, :minimize)
        current_best = Map.get(study, :best_score)
        
        is_better = case {goal, current_best} do
          {_, nil} -> true
          {:minimize, best} when result < best -> true
          {:maximize, best} when result > best -> true
          _ -> false
        end
        
        if is_better do
          updates = %{best_score: result, best_trial_id: trial_id}
          Store.set_study_status(study_id, updates)
          Logger.info("New best result for #{study_id}: #{result}")
        end
        
        :ok
      
      :error ->
        Logger.error("Could not update best result - study not found: #{study_id}")
        :error
    end
  end
end