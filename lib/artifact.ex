defmodule Scout.Artifact do
  @moduledoc """
  Artifact storage system for Scout trials.
  
  Stores and manages trial artifacts like:
  - Trained models
  - Plots and visualizations
  - Intermediate results
  - Configuration files
  - Logs and metrics
  
  Equivalent to Optuna's artifact management.
  """
  
  @default_storage_path ".scout/artifacts"
  
  defstruct [
    :id,
    :trial_id,
    :study_id,
    :name,
    :type,
    :path,
    :metadata,
    :created_at,
    :size_bytes,
    :checksum
  ]
  
  @doc """
  Initializes the artifact storage system.
  """
  def init(opts \\ []) do
    storage_path = Keyword.get(opts, :storage_path, @default_storage_path)
    
    # Create storage directory if it doesn't exist
    File.mkdir_p!(storage_path)
    
    %{
      storage_path: storage_path,
      backend: Keyword.get(opts, :backend, :local),  # :local, :s3, :gcs
      compression: Keyword.get(opts, :compression, false),
      max_size_mb: Keyword.get(opts, :max_size_mb, 100)
    }
  end
  
  @doc """
  Stores an artifact for a trial.
  
  ## Examples
  
      # Store a model file
      Scout.Artifact.store(trial_id, "model.pkl", :model,
        data: model_binary,
        metadata: %{framework: "sklearn", accuracy: 0.95}
      )
      
      # Store a plot
      Scout.Artifact.store(trial_id, "loss_curve.png", :plot,
        file_path: "/tmp/plot.png",
        metadata: %{format: "png", dpi: 300}
      )
  """
  def store(trial_id, name, type, opts \\ []) do
    study_id = Keyword.get(opts, :study_id)
    metadata = Keyword.get(opts, :metadata, %{})
    storage_config = Keyword.get(opts, :storage_config, init())
    
    # Generate artifact ID
    artifact_id = generate_id(trial_id, name)
    
    # Determine storage path
    relative_path = build_path(study_id, trial_id, name, type)
    full_path = Path.join(storage_config.storage_path, relative_path)
    
    # Ensure directory exists
    File.mkdir_p!(Path.dirname(full_path))
    
    # Store the artifact
    size_bytes = case Keyword.get(opts, :data) do
      nil ->
        # Copy from file
        source_path = Keyword.fetch!(opts, :file_path)
        copy_artifact(source_path, full_path, storage_config)
        
      data when is_binary(data) ->
        # Write binary data
        write_artifact(data, full_path, storage_config)
        
      data ->
        # Serialize and write
        serialized = serialize(data, type)
        write_artifact(serialized, full_path, storage_config)
    end
    
    # Calculate checksum
    checksum = calculate_checksum(full_path)
    
    # Create artifact record
    artifact = %__MODULE__{
      id: artifact_id,
      trial_id: trial_id,
      study_id: study_id,
      name: name,
      type: type,
      path: relative_path,
      metadata: metadata,
      created_at: DateTime.utc_now(),
      size_bytes: size_bytes,
      checksum: checksum
    }
    
    # Store metadata in database/index
    store_metadata(artifact)
    
    {:ok, artifact}
  rescue
    e -> {:error, e}
  end
  
  @doc """
  Retrieves an artifact.
  """
  def get(artifact_id, opts \\ []) do
    storage_config = Keyword.get(opts, :storage_config, init())
    
    # Load metadata
    case load_metadata(artifact_id) do
      {:ok, artifact} ->
        full_path = Path.join(storage_config.storage_path, artifact.path)
        
        if File.exists?(full_path) do
          # Verify checksum
          if verify_checksum(full_path, artifact.checksum) do
            {:ok, artifact, full_path}
          else
            {:error, :checksum_mismatch}
          end
        else
          {:error, :not_found}
        end
        
      error -> error
    end
  end
  
  @doc """
  Loads artifact data into memory.
  """
  def load(artifact_id, opts \\ []) do
    case get(artifact_id, opts) do
      {:ok, artifact, path} ->
        data = read_artifact(path, artifact, Keyword.get(opts, :storage_config, init()))
        {:ok, data}
      error -> error
    end
  end
  
  @doc """
  Lists artifacts for a trial or study.
  """
  def list(scope, scope_id, opts \\ []) do
    filters = case scope do
      :trial -> %{trial_id: scope_id}
      :study -> %{study_id: scope_id}
    end
    
    # Add additional filters
    filters = if type = Keyword.get(opts, :type) do
      Map.put(filters, :type, type)
    else
      filters
    end
    
    query_metadata(filters)
  end
  
  @doc """
  Deletes an artifact.
  """
  def delete(artifact_id, opts \\ []) do
    storage_config = Keyword.get(opts, :storage_config, init())
    
    case get(artifact_id, storage_config: storage_config) do
      {:ok, _artifact, path} ->
        # Delete file
        File.rm(path)
        
        # Delete metadata
        delete_metadata(artifact_id)
        
        :ok
        
      error -> error
    end
  end
  
  @doc """
  Creates a temporary file for artifact generation.
  """
  def temp_file(extension \\ "") do
    temp_dir = System.tmp_dir!()
    name = "scout_artifact_#{System.unique_integer([:positive])}#{extension}"
    Path.join(temp_dir, name)
  end
  
  # Storage backends
  
  defp copy_artifact(source, dest, config) do
    case config.backend do
      :local ->
        File.cp!(source, dest)
        %File.Stat{size: size} = File.stat!(dest)
        
        if config.compression do
          compress_file(dest)
        else
          size
        end
        
      :s3 ->
        upload_to_s3(source, dest, config)
        
      :gcs ->
        upload_to_gcs(source, dest, config)
    end
  end
  
  defp write_artifact(data, path, config) do
    data_to_write = if config.compression do
      compress_data(data)
    else
      data
    end
    
    case config.backend do
      :local ->
        File.write!(path, data_to_write)
        byte_size(data_to_write)
        
      :s3 ->
        upload_data_to_s3(data_to_write, path, config)
        
      :gcs ->
        upload_data_to_gcs(data_to_write, path, config)
    end
  end
  
  defp read_artifact(path, artifact, config) do
    raw_data = case config.backend do
      :local ->
        File.read!(path)
        
      :s3 ->
        download_from_s3(path, config)
        
      :gcs ->
        download_from_gcs(path, config)
    end
    
    data = if config.compression do
      decompress_data(raw_data)
    else
      raw_data
    end
    
    # Deserialize if needed
    deserialize(data, artifact.type)
  end
  
  # Serialization
  
  defp serialize(data, :model) do
    # Serialize model using :erlang.term_to_binary
    :erlang.term_to_binary(data)
  end
  
  defp serialize(data, :dataframe) do
    # Serialize dataframe/table
    :erlang.term_to_binary(data)
  end
  
  defp serialize(data, :json) do
    Jason.encode!(data)
  end
  
  defp serialize(data, _type) do
    # Default serialization
    :erlang.term_to_binary(data)
  end
  
  defp deserialize(data, :model) do
    :erlang.binary_to_term(data)
  end
  
  defp deserialize(data, :dataframe) do
    :erlang.binary_to_term(data)
  end
  
  defp deserialize(data, :json) do
    Jason.decode!(data)
  end
  
  defp deserialize(data, :text) do
    data
  end
  
  defp deserialize(data, :plot) do
    # Return binary image data
    data
  end
  
  defp deserialize(data, _type) do
    # Try to deserialize as Erlang term
    try do
      :erlang.binary_to_term(data)
    rescue
      _ -> data
    end
  end
  
  # Compression
  
  defp compress_data(data) do
    :zlib.compress(data)
  end
  
  defp decompress_data(data) do
    :zlib.uncompress(data)
  end
  
  defp compress_file(path) do
    data = File.read!(path)
    compressed = compress_data(data)
    File.write!(path <> ".gz", compressed)
    File.rm!(path)
    File.rename!(path <> ".gz", path)
    byte_size(compressed)
  end
  
  # Checksums
  
  defp calculate_checksum(path) do
    File.stream!(path, [], 2048)
    |> Enum.reduce(:crypto.hash_init(:sha256), &:crypto.hash_update(&2, &1))
    |> :crypto.hash_final()
    |> Base.encode16(case: :lower)
  end
  
  defp verify_checksum(path, expected) do
    actual = calculate_checksum(path)
    actual == expected
  end
  
  # Path management
  
  defp build_path(study_id, trial_id, name, type) do
    study_part = study_id || "no_study"
    type_part = Atom.to_string(type)
    
    Path.join([
      study_part,
      "trial_#{trial_id}",
      type_part,
      name
    ])
  end
  
  defp generate_id(trial_id, name) do
    timestamp = System.os_time(:microsecond)
    hash = :crypto.hash(:md5, "#{trial_id}_#{name}_#{timestamp}")
    |> Base.encode16(case: :lower)
    |> String.slice(0..7)
    
    "artifact_#{hash}"
  end
  
  # Metadata storage (simplified - would use database in production)
  
  @metadata_file ".scout/artifacts/metadata.etf"
  
  defp store_metadata(artifact) do
    metadata = load_all_metadata()
    updated = Map.put(metadata, artifact.id, artifact)
    save_all_metadata(updated)
  end
  
  defp load_metadata(artifact_id) do
    metadata = load_all_metadata()
    
    case Map.get(metadata, artifact_id) do
      nil -> {:error, :not_found}
      artifact -> {:ok, artifact}
    end
  end
  
  defp query_metadata(filters) do
    load_all_metadata()
    |> Map.values()
    |> Enum.filter(fn artifact ->
      Enum.all?(filters, fn {key, value} ->
        Map.get(artifact, key) == value
      end)
    end)
  end
  
  defp delete_metadata(artifact_id) do
    metadata = load_all_metadata()
    updated = Map.delete(metadata, artifact_id)
    save_all_metadata(updated)
  end
  
  defp load_all_metadata() do
    if File.exists?(@metadata_file) do
      File.read!(@metadata_file)
      |> :erlang.binary_to_term()
    else
      %{}
    end
  end
  
  defp save_all_metadata(metadata) do
    File.mkdir_p!(Path.dirname(@metadata_file))
    data = :erlang.term_to_binary(metadata)
    File.write!(@metadata_file, data)
  end
  
  # Cloud storage stubs
  
  defp upload_to_s3(_source, _dest, _config) do
    # Would implement S3 upload using ExAws
    raise "S3 backend not implemented"
  end
  
  defp upload_data_to_s3(_data, _path, _config) do
    raise "S3 backend not implemented"
  end
  
  defp download_from_s3(_path, _config) do
    raise "S3 backend not implemented"
  end
  
  defp upload_to_gcs(_source, _dest, _config) do
    # Would implement GCS upload
    raise "GCS backend not implemented"
  end
  
  defp upload_data_to_gcs(_data, _path, _config) do
    raise "GCS backend not implemented"
  end
  
  defp download_from_gcs(_path, _config) do
    raise "GCS backend not implemented"
  end
  
  @doc """
  Helper to store matplotlib-style plots.
  """
  def store_plot(trial_id, plot_data, name \\ "plot.png", opts \\ []) do
    store(trial_id, name, :plot, Keyword.merge(opts, [data: plot_data]))
  end
  
  @doc """
  Helper to store model checkpoints.
  """
  def store_model(trial_id, model, name \\ "model.ckpt", opts \\ []) do
    store(trial_id, name, :model, Keyword.merge(opts, [data: model]))
  end
  
  @doc """
  Helper to store metrics/logs.
  """
  def store_metrics(trial_id, metrics, name \\ "metrics.json", opts \\ []) do
    store(trial_id, name, :json, Keyword.merge(opts, [data: metrics]))
  end
  
  @doc """
  Garbage collection for old artifacts.
  """
  def cleanup(opts \\ []) do
    max_age_days = Keyword.get(opts, :max_age_days, 30)
    max_size_gb = Keyword.get(opts, :max_size_gb, 10)
    
    cutoff_date = DateTime.utc_now()
    |> DateTime.add(-max_age_days * 24 * 3600, :second)
    
    artifacts = load_all_metadata()
    |> Map.values()
    
    # Delete old artifacts
    old_artifacts = Enum.filter(artifacts, fn a ->
      DateTime.compare(a.created_at, cutoff_date) == :lt
    end)
    
    Enum.each(old_artifacts, fn a ->
      delete(a.id)
    end)
    
    # Check total size
    total_size = artifacts
    |> Enum.map(& &1.size_bytes)
    |> Enum.sum()
    
    if total_size > max_size_gb * 1024 * 1024 * 1024 do
      # Delete oldest artifacts until under limit
      artifacts
      |> Enum.sort_by(& &1.created_at)
      |> Enum.reduce_while(total_size, fn a, acc ->
        if acc > max_size_gb * 1024 * 1024 * 1024 do
          delete(a.id)
          {:cont, acc - a.size_bytes}
        else
          {:halt, acc}
        end
      end)
    end
    
    :ok
  end
end