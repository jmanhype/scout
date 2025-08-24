defmodule Scout.StudyRunner do
  @moduledoc """
  Study execution orchestrator that delegates to the appropriate executor.
  
  By default uses Iterative executor, but respects the study's executor field
  if specified.
  """
  
  alias Scout.Executor.Iterative
  
  @doc """
  Runs a study using the configured executor.
  
  If the study has an executor field set, that executor will be used.
  Otherwise defaults to Scout.Executor.Iterative.
  """
  def run(%Scout.Study{executor: exec_mod} = study) when is_atom(exec_mod) and not is_nil(exec_mod) do
    exec_mod.run(study)
  end
  
  def run(%Scout.Study{} = study) do
    Iterative.run(study)
  end
end