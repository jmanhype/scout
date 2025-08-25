defmodule Scout.Format do
  @moduledoc """
  Format validation and normalization for Scout data structures.
  
  Ensures consistency between internal representations and external APIs.
  Uses JSON schemas to validate payloads in dev/test.
  """
  
  @app :scout_core
  
  # Load schemas from app priv dir (works in umbrella structure)
  @study_schema Path.join(:code.priv_dir(@app), "schema/study.schema.json") |> File.read!() |> Jason.decode!()
  @trial_schema Path.join(:code.priv_dir(@app), "schema/trial.schema.json") |> File.read!() |> Jason.decode!()
  
  @doc """
  Validate a study map against the JSON schema.
  
  Returns :ok or {:error, violations} in dev/test.
  No-op in production for performance.
  """
  def validate_study!(study_map) when is_map(study_map) do
    if Mix.env() in [:dev, :test] do
      case validate_against_schema(study_map, @study_schema) do
        :ok -> :ok
        {:error, errors} ->
          raise "Study format validation failed: #{inspect(errors)}"
      end
    end
    :ok
  end
  
  @doc """
  Validate a trial map against the JSON schema.
  """
  def validate_trial!(trial_map) when is_map(trial_map) do
    if Mix.env() in [:dev, :test] do
      case validate_against_schema(trial_map, @trial_schema) do
        :ok -> :ok
        {:error, errors} ->
          raise "Trial format validation failed: #{inspect(errors)}"
      end
    end
    :ok
  end
  
  @doc """
  Normalize status values between string/atom representations.
  """
  def normalize_status(status) when is_atom(status), do: status
  def normalize_status(status) when is_binary(status) do
    String.to_existing_atom(status)
  rescue
    ArgumentError -> raise "Invalid status: #{status}"
  end
  
  @doc """
  Normalize goal values between string/atom representations.
  """
  def normalize_goal(goal) when is_atom(goal), do: goal
  def normalize_goal(goal) when is_binary(goal) do
    String.to_existing_atom(goal)
  rescue
    ArgumentError -> raise "Invalid goal: #{goal}"
  end
  
  # Simple schema validation (production would use ex_json_schema)
  defp validate_against_schema(data, schema) do
    # Basic validation - check required fields
    required = Map.get(schema, "required", [])
    
    missing = Enum.reject(required, fn field ->
      Map.has_key?(data, field) or Map.has_key?(data, String.to_existing_atom(field))
    end)
    
    if Enum.empty?(missing) do
      :ok
    else
      {:error, "Missing required fields: #{Enum.join(missing, ", ")}"}
    end
  end
end