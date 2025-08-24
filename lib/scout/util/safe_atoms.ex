defmodule Scout.Util.SafeAtoms do
  @moduledoc """
  Security hardening: prevent atom table exhaustion and RCE via String.to_atom/1.
  Only allows whitelisted atoms from user input.
  """

  @valid_goals ~w(maximize minimize)a
  @valid_samplers ~w(random tpe bandit grid)a
  @valid_pruners ~w(median hyperband successive_halving)a
  @valid_statuses ~w(pending running completed failed pruned)a

  @goal_map %{
    "maximize" => :maximize,
    "minimize" => :minimize
  }

  @sampler_map %{
    "random" => :random,
    "tpe" => :tpe,
    "bandit" => :bandit,
    "grid" => :grid
  }

  @pruner_map %{
    "median" => :median,
    "hyperband" => :hyperband,
    "successive_halving" => :successive_halving,
    "sha" => :successive_halving  # alias
  }

  @status_map %{
    "pending" => :pending,
    "running" => :running,
    "completed" => :completed,
    "failed" => :failed,
    "pruned" => :pruned
  }

  @spec goal_from_string!(String.t()) :: :maximize | :minimize
  def goal_from_string!(s) when is_binary(s) do
    case Map.fetch(@goal_map, String.downcase(s)) do
      {:ok, atom} -> atom
      :error -> raise ArgumentError, "unsupported goal: #{inspect(s)}. Valid: #{Map.keys(@goal_map)}"
    end
  end

  @spec sampler_from_string!(String.t()) :: atom()
  def sampler_from_string!(s) when is_binary(s) do
    case Map.fetch(@sampler_map, String.downcase(s)) do
      {:ok, atom} -> atom
      :error -> raise ArgumentError, "unsupported sampler: #{inspect(s)}. Valid: #{Map.keys(@sampler_map)}"
    end
  end

  @spec pruner_from_string!(String.t()) :: atom()
  def pruner_from_string!(s) when is_binary(s) do
    case Map.fetch(@pruner_map, String.downcase(s)) do
      {:ok, atom} -> atom
      :error -> raise ArgumentError, "unsupported pruner: #{inspect(s)}. Valid: #{Map.keys(@pruner_map)}"
    end
  end

  @spec status_from_string!(String.t()) :: atom()
  def status_from_string!(s) when is_binary(s) do
    case Map.fetch(@status_map, String.downcase(s)) do
      {:ok, atom} -> atom
      :error -> raise ArgumentError, "unsupported status: #{inspect(s)}. Valid: #{Map.keys(@status_map)}"
    end
  end

  @doc "Get all valid atoms for a category"
  def valid_goals, do: @valid_goals
  def valid_samplers, do: @valid_samplers
  def valid_pruners, do: @valid_pruners
  def valid_statuses, do: @valid_statuses
end