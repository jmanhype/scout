defmodule Scout.Executor do
  @moduledoc """
  Behaviour for Scout execution strategies.
  
  Executors handle how trials are run - locally, distributed, with pruning, etc.
  Each executor must implement the run/1 callback to execute a study.
  """
  
  @doc """
  Runs a study and returns the best result.
  
  ## Parameters
    - study: A Scout.Study struct containing the optimization configuration
    
  ## Returns
    - {:ok, result} where result contains the best parameters and score
    - {:error, reason} if execution fails
  """
  @callback run(Scout.Study.t()) :: {:ok, map()} | {:error, term()}
end