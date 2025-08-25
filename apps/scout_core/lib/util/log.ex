# Purpose: centralized, future-proof logger wrappers to eliminate churn
defmodule Scout.Log do
  @moduledoc "Thin wrappers over Logger to absorb deprecations and unify metadata."
  require Logger
  
  def info(msg, md \\ %{}), do: Logger.info(fn -> {msg, md} end)
  def warning(msg, md \\ %{}), do: Logger.warning(fn -> {msg, md} end)
  def error(msg, md \\ %{}), do: Logger.error(fn -> {msg, md} end)
  def debug(msg, md \\ %{}), do: Logger.debug(fn -> {msg, md} end)
end