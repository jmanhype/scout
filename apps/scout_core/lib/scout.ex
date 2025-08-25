defmodule Scout do
  alias Scout.{Study, StudyRunner}
  @spec run(Study.t()) :: {:ok, map()} | {:error, term()}
  def run(%Study{} = s), do: StudyRunner.run(s)
end
