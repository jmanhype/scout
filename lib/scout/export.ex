defmodule Scout.Export do
  @moduledoc """
  Export functionality for Scout optimization results.
  
  Supports exporting study data to CSV and JSON formats for external analysis.
  """
  
  alias Scout.Store
  
  @doc """
  Export study results to JSON format.
  
  ## Options
    - `:pretty` - Pretty print JSON (default: true)
    - `:include_metadata` - Include study metadata (default: true)
  
  ## Examples
  
      Scout.Export.to_json("my-study")
      #=> {:ok, json_string}
      
      Scout.Export.to_json("my-study", pretty: false)
      #=> {:ok, compact_json}
  """
  @spec to_json(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def to_json(study_id, opts \\ []) do
    pretty = Keyword.get(opts, :pretty, true)
    include_metadata = Keyword.get(opts, :include_metadata, true)
    
    with {:ok, data} <- build_export_data(study_id, include_metadata) do
      encoder_opts = if pretty, do: [pretty: true], else: []
      
      case Jason.encode(data, encoder_opts) do
        {:ok, json} -> {:ok, json}
        {:error, reason} -> {:error, {:json_encode_error, reason}}
      end
    end
  end
  
  @doc """
  Export study results to CSV format.
  
  ## Options
    - `:headers` - Include header row (default: true)
    - `:separator` - CSV separator (default: ",")
  
  ## Examples
  
      Scout.Export.to_csv("my-study")
      #=> {:ok, csv_string}
      
      Scout.Export.to_csv("my-study", separator: ";")
      #=> {:ok, csv_with_semicolons}
  """
  @spec to_csv(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def to_csv(study_id, opts \\ []) do
    headers = Keyword.get(opts, :headers, true)
    separator = Keyword.get(opts, :separator, ",")
    
    case Store.get_study(study_id) do
      {:ok, study} ->
        trials = Store.list_trials(study_id)
        csv_data = build_csv_rows(study, trials, headers, separator)
        {:ok, csv_data}
        
      :error ->
        {:error, :study_not_found}
    end
  end
  
  @doc """
  Save study results to a file.
  
  ## Options
    - `:format` - Export format (:json or :csv, default: :json)
    - Plus format-specific options
  
  ## Examples
  
      Scout.Export.to_file("my-study", "results.json")
      #=> :ok
      
      Scout.Export.to_file("my-study", "results.csv", format: :csv)
      #=> :ok
  """
  @spec to_file(String.t(), String.t(), keyword()) :: :ok | {:error, term()}
  def to_file(study_id, file_path, opts \\ []) do
    format = Keyword.get(opts, :format, :json)
    format_opts = Keyword.delete(opts, :format)
    
    with {:ok, content} <- export_content(study_id, format, format_opts) do
      File.write(file_path, content)
    end
  end
  
  @doc """
  Get study statistics summary.
  
  Returns a map with study statistics including best value, number of trials,
  convergence information, and parameter distributions.
  
  ## Examples
  
      Scout.Export.study_stats("my-study")
      #=> {:ok, %{best_value: 0.123, n_trials: 100, ...}}
  """
  @spec study_stats(String.t()) :: {:ok, map()} | {:error, term()}
  def study_stats(study_id) do
    case Store.get_study(study_id) do
      {:ok, study} ->
        trials = Store.list_trials(study_id)
        stats = calculate_statistics(study, trials)
        {:ok, stats}
        
      :error ->
        {:error, :study_not_found}
    end
  end
  
  # Private functions
  
  defp export_content(study_id, :json, opts), do: to_json(study_id, opts)
  defp export_content(study_id, :csv, opts), do: to_csv(study_id, opts)
  defp export_content(_study_id, format, _opts), do: {:error, {:unsupported_format, format}}
  
  defp build_export_data(study_id, include_metadata) do
    case Store.get_study(study_id) do
      {:ok, study} ->
        trials = Store.list_trials(study_id)
        
        data = %{
          study_id: study_id,
          goal: study[:goal] || study["goal"],
          n_trials: length(trials),
          trials: format_trials(trials)
        }
        
        data = if include_metadata do
          Map.merge(data, %{
            metadata: study[:metadata] || study["metadata"] || %{},
            created_at: study[:created_at] || study["created_at"],
            sampler: study[:sampler] || study["sampler"],
            pruner: study[:pruner] || study["pruner"]
          })
        else
          data
        end
        
        {:ok, data}
        
      :error ->
        {:error, :study_not_found}
    end
  end
  
  defp format_trials(trials) do
    Enum.map(trials, fn trial ->
      # Handle both struct and map formats
      case trial do
        %Scout.Trial{} = t ->
          %{
            id: t.id,
            params: t.params,
            value: t.score,
            status: t.status,
            started_at: t.started_at,
            completed_at: t.finished_at
          }
          
        _ ->
          %{
            id: trial[:id] || trial["id"],
            params: trial[:params] || trial["params"],
            value: trial[:value] || trial["value"] || trial[:score] || trial["score"],
            status: trial[:status] || trial["status"],
            started_at: trial[:started_at] || trial["started_at"],
            completed_at: trial[:completed_at] || trial["completed_at"]
          }
      end
    end)
  end
  
  defp build_csv_rows(_study, trials, include_headers, separator) do
    # Get all unique parameter names
    param_names = trials
    |> Enum.flat_map(fn t -> 
      params = case t do
        %Scout.Trial{params: p} -> p
        _ -> t[:params] || t["params"] || %{}
      end
      Map.keys(params)
    end)
    |> Enum.uniq()
    |> Enum.sort()
    
    # Build header row
    headers = if include_headers do
      header_cols = ["trial_id", "value", "status"] ++ Enum.map(param_names, &"param_#{&1}")
      Enum.join(header_cols, separator) <> "\n"
    else
      ""
    end
    
    # Build data rows
    rows = Enum.map(trials, fn trial ->
      {id, value, status, params} = case trial do
        %Scout.Trial{} = t ->
          {t.id, t.score, t.status, t.params}
        _ ->
          {
            trial[:id] || trial["id"] || "",
            trial[:value] || trial["value"] || trial[:score] || trial["score"] || "",
            trial[:status] || trial["status"] || "",
            trial[:params] || trial["params"] || %{}
          }
      end
      
      param_values = Enum.map(param_names, fn name ->
        to_string(Map.get(params, name, ""))
      end)
      
      cols = [to_string(id), to_string(value), to_string(status)] ++ param_values
      Enum.join(cols, separator)
    end)
    
    headers <> Enum.join(rows, "\n")
  end
  
  defp calculate_statistics(study, trials) do
    completed_trials = Enum.filter(trials, fn t ->
      status = case t do
        %Scout.Trial{status: s} -> s
        _ -> t[:status] || t["status"]
      end
      status in [:completed, "completed", :succeeded, "succeeded"]
    end)
    
    values = Enum.map(completed_trials, fn t ->
      case t do
        %Scout.Trial{score: s} -> s
        _ -> t[:value] || t["value"] || t[:score] || t["score"] || 0
      end
    end)
    
    goal = study[:goal] || study["goal"] || :minimize
    
    best_value = if Enum.empty?(values) do
      nil
    else
      case goal do
        g when g in [:minimize, "minimize"] -> Enum.min(values)
        g when g in [:maximize, "maximize"] -> Enum.max(values)
        _ -> Enum.min(values)
      end
    end
    
    %{
      study_id: study[:id] || study["id"],
      goal: goal,
      n_trials: length(trials),
      n_completed: length(completed_trials),
      n_pruned: count_pruned(trials),
      best_value: best_value,
      mean_value: mean(values),
      std_value: std_dev(values),
      min_value: if(Enum.empty?(values), do: nil, else: Enum.min(values)),
      max_value: if(Enum.empty?(values), do: nil, else: Enum.max(values))
    }
  end
  
  defp count_pruned(trials) do
    Enum.count(trials, fn t ->
      status = case t do
        %Scout.Trial{status: s} -> s
        _ -> t[:status] || t["status"]
      end
      status in [:pruned, "pruned"]
    end)
  end
  
  defp mean([]), do: nil
  defp mean(values) do
    Enum.sum(values) / length(values)
  end
  
  defp std_dev([]), do: nil
  defp std_dev([_]), do: 0.0
  defp std_dev(values) do
    avg = mean(values)
    variance = Enum.sum(Enum.map(values, fn x -> :math.pow(x - avg, 2) end)) / length(values)
    :math.sqrt(variance)
  end
end