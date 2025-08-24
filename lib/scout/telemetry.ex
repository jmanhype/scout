defmodule Scout.Telemetry do
  def study_event(type, meas \\ %{}, meta \\ %{}) do
    # Try to use telemetry if available, otherwise silently skip
    try do
      :telemetry.execute([:scout, :study, type], meas, meta)
    rescue
      UndefinedFunctionError -> :ok
    end
  end
  
  def trial_event(type, meas \\ %{}, meta \\ %{}) do
    # Try to use telemetry if available, otherwise silently skip
    try do
      :telemetry.execute([:scout, :trial, type], meas, meta)
    rescue
      UndefinedFunctionError -> :ok
    end
  end
end
