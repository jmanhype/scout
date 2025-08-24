defmodule Scout.StudyRunner do
  @moduledoc false
  alias Scout.Executor.Iterative
  def run(%Scout.Study{} = study), do: Iterative.run(study)
end
