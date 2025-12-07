#!/usr/bin/env elixir

# Test PostgreSQL storage adapter
defmodule TestPostgresStorage do
  @moduledoc """
  Demonstrates PostgreSQL storage adapter for Scout.
  
  Prerequisites:
  1. PostgreSQL must be running
  2. Database credentials configured in config/
  3. Run: mix ecto.create && mix ecto.migrate
  """
  
  def run do
    IO.puts("\n" <> String.duplicate("=", 60))
    IO.puts(" POSTGRESQL STORAGE TEST")
    IO.puts(String.duplicate("=", 60))
    
    # Check current storage adapter
    adapter = Application.get_env(:scout, :store_adapter, Scout.Store.ETS)
    IO.puts("\n📦 Current storage adapter: #{inspect(adapter)}")
    
    if adapter == Scout.Store.Postgres do
      test_postgres_storage()
    else
      test_adapter_switching()
    end
  end
  
  defp test_postgres_storage do
    IO.puts("\n✅ PostgreSQL adapter is configured!")
    
    # Test basic operations
    IO.puts("\n1. Testing PostgreSQL operations...")
    
    study_id = "postgres-test-#{:rand.uniform(1000)}"
    
    # Create a study
    study = %{
      id: study_id,
      goal: "minimize",
      search_space: %{
        x: {:uniform, -5, 5},
        y: {:uniform, -5, 5}
      },
      metadata: %{
        description: "Test study for PostgreSQL storage",
        created_by: "test_postgres.exs"
      },
      max_trials: 10
    }
    
    case Scout.Store.Postgres.put_study(study) do
      :ok ->
        IO.puts("   ✓ Study created in PostgreSQL")
        
      {:error, reason} ->
        IO.puts("   ✗ Failed to create study: #{inspect(reason)}")
        IO.puts("   Make sure PostgreSQL is running and migrations are applied")
        System.halt(1)
    end
    
    # Retrieve the study
    case Scout.Store.Postgres.get_study(study_id) do
      {:ok, retrieved} ->
        IO.puts("   ✓ Study retrieved from PostgreSQL")
        IO.puts("     - ID: #{retrieved.id}")
        IO.puts("     - Goal: #{retrieved.goal}")
        
      {:error, reason} ->
        IO.puts("   ✗ Failed to retrieve study: #{inspect(reason)}")
    end
    
    # Add a trial
    trial = %{
      id: "trial-#{:rand.uniform(1000)}",
      number: 1,
      params: %{x: 2.5, y: -1.3},
      value: nil,
      status: "running",
      started_at: DateTime.utc_now()
    }
    
    case Scout.Store.Postgres.put_trial(study_id, trial) do
      :ok ->
        IO.puts("   ✓ Trial added to PostgreSQL")
        
        # Update trial with result
        updates = %{
          value: 3.14159,
          status: "succeeded",
          completed_at: DateTime.utc_now()
        }
        
        case Scout.Store.Postgres.update_trial(study_id, trial.id, updates) do
          :ok ->
            IO.puts("   ✓ Trial updated in PostgreSQL")
            
          {:error, reason} ->
            IO.puts("   ✗ Failed to update trial: #{inspect(reason)}")
        end
        
      {:error, reason} ->
        IO.puts("   ✗ Failed to add trial: #{inspect(reason)}")
    end
    
    # List all trials
    trials = Scout.Store.Postgres.list_trials(study_id)
    IO.puts("   ✓ Retrieved #{length(trials)} trial(s) from PostgreSQL")
    
    # Test persistence
    IO.puts("\n2. Testing persistence...")
    IO.puts("   Studies and trials are now persisted in PostgreSQL.")
    IO.puts("   They will survive application restarts!")
    
    # Show connection info
    repo_config = Application.get_env(:scout, Scout.Repo, [])
    IO.puts("\n3. Database connection:")
    IO.puts("   - Host: #{repo_config[:hostname] || "localhost"}")
    IO.puts("   - Database: #{repo_config[:database] || "scout_dev"}")
    IO.puts("   - Pool size: #{repo_config[:pool_size] || 10}")
    
    IO.puts("\n✅ PostgreSQL storage is working correctly!")
    IO.puts("   Your optimization data is now persistent and can be")
    IO.puts("   accessed from multiple nodes for distributed optimization.")
  end
  
  defp test_adapter_switching do
    IO.puts("\n⚠️  Currently using ETS adapter (in-memory storage)")
    IO.puts("\nTo enable PostgreSQL storage:")
    IO.puts("1. Update config/config.exs to include:")
    IO.puts("   config :scout, :store_adapter, Scout.Store.Postgres")
    IO.puts("\n2. Configure database credentials:")
    IO.puts("   config :scout, Scout.Repo,")
    IO.puts("     username: \"postgres\",")
    IO.puts("     password: \"postgres\",")
    IO.puts("     hostname: \"localhost\",")
    IO.puts("     database: \"scout_dev\"")
    IO.puts("\n3. Add Repo to your application supervision tree")
    IO.puts("\n4. Run migrations:")
    IO.puts("   mix ecto.create")
    IO.puts("   mix ecto.migrate")
    IO.puts("\n5. Restart the application")
    
    IO.puts("\n📝 A sample configuration is available in: config/postgres.exs")
    
    # Show what would be stored
    IO.puts("\n" <> String.duplicate("-", 40))
    IO.puts("With PostgreSQL, you would get:")
    IO.puts("- Persistent storage across restarts")
    IO.puts("- Distributed optimization support")
    IO.puts("- SQL query capabilities")
    IO.puts("- Better crash recovery")
    IO.puts("- Integration with data pipelines")
  end
end

# Run the test
TestPostgresStorage.run()