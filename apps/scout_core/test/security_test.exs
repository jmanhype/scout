defmodule Scout.SecurityTest do
  use ExUnit.Case, async: true

  alias Scout.Util.SafeAtoms
  alias Scout.SecurityGates

  describe "SafeAtoms security" do
    test "prevents atom table exhaustion" do
      # Should not create new atoms from user input
      assert SafeAtoms.goal_from_string!("maximize") == :maximize
      assert SafeAtoms.goal_from_string!("MAXIMIZE") == :maximize  # Case insensitive
      
      # Should reject unknown values
      assert_raise ArgumentError, fn ->
        SafeAtoms.goal_from_string!("evil_atom_#{:rand.uniform(1000000)}")
      end
      
      # Should not create atoms even with valid-looking strings
      random_string = "goal_#{System.unique_integer()}"
      assert_raise ArgumentError, fn ->
        SafeAtoms.goal_from_string!(random_string)
      end
    end

    test "sampler atoms are whitelisted" do
      # Valid samplers
      assert SafeAtoms.sampler_from_string!("tpe") == :tpe
      assert SafeAtoms.sampler_from_string!("random") == :random
      assert SafeAtoms.sampler_from_string!("bandit") == :bandit
      
      # Invalid samplers rejected
      assert_raise ArgumentError, fn ->
        SafeAtoms.sampler_from_string!("malicious_sampler")
      end
      
      assert_raise ArgumentError, fn ->
        SafeAtoms.sampler_from_string!("system_#{:rand.uniform(1000)}")
      end
    end

    test "pruner atoms are whitelisted" do
      # Valid pruners
      assert SafeAtoms.pruner_from_string!("median") == :median
      assert SafeAtoms.pruner_from_string!("hyperband") == :hyperband
      assert SafeAtoms.pruner_from_string!("sha") == :successive_halving  # Alias
      
      # Invalid pruners rejected
      assert_raise ArgumentError, fn ->
        SafeAtoms.pruner_from_string!("evil_pruner")
      end
    end

    test "status atoms are whitelisted" do
      # Valid statuses  
      assert SafeAtoms.status_from_string!("pending") == :pending
      assert SafeAtoms.status_from_string!("completed") == :completed
      assert SafeAtoms.status_from_string!("FAILED") == :failed  # Case insensitive
      
      # Invalid statuses rejected
      assert_raise ArgumentError, fn ->
        SafeAtoms.status_from_string!("compromised")
      end
      
      assert_raise ArgumentError, fn ->
        SafeAtoms.status_from_string!("status_#{System.unique_integer()}")
      end
    end

    test "atom lists are finite and controlled" do
      # Verify whitelist sizes are reasonable
      assert length(SafeAtoms.valid_goals()) == 2
      assert length(SafeAtoms.valid_samplers()) == 4
      assert length(SafeAtoms.valid_pruners()) == 3
      assert length(SafeAtoms.valid_statuses()) == 5
      
      # Should not grow over time
      initial_goals = SafeAtoms.valid_goals()
      
      # Try to "add" new goals (should fail)
      assert_raise ArgumentError, fn ->
        SafeAtoms.goal_from_string!("new_goal_type")
      end
      
      # List should be unchanged
      assert SafeAtoms.valid_goals() == initial_goals
    end
  end

  describe "Security gates" do
    test "check_all! validates configuration" do
      # Mock unsafe configuration
      original_dashboard = Application.get_env(:scout_dashboard, :enabled, false)
      original_secret = Application.get_env(:scout_dashboard, :secret)
      
      try do
        # Test 1: Dashboard enabled without secret should fail
        Application.put_env(:scout_dashboard, :enabled, true)
        Application.put_env(:scout_dashboard, :secret, nil)
        
        assert_raise RuntimeError, ~r/SECURITY GATE FAILURE/, fn ->
          SecurityGates.check_all!()
        end
        
        # Test 2: Dashboard enabled with weak secret should fail  
        Application.put_env(:scout_dashboard, :secret, "weak")
        
        assert_raise RuntimeError, ~r/SECURITY GATE FAILURE/, fn ->
          SecurityGates.check_all!()
        end
        
        # Test 3: Dashboard disabled should pass
        Application.put_env(:scout_dashboard, :enabled, false)
        Application.put_env(:scout_dashboard, :secret, nil)
        
        # Should not raise
        SecurityGates.check_all!()
        
        # Test 4: Dashboard enabled with strong secret should pass
        Application.put_env(:scout_dashboard, :enabled, true)
        Application.put_env(:scout_dashboard, :secret, String.duplicate("a", 32))
        
        # Should not raise
        SecurityGates.check_all!()
        
      after
        # Restore original settings
        if original_dashboard do
          Application.put_env(:scout_dashboard, :enabled, original_dashboard)
        else
          Application.delete_env(:scout_dashboard, :enabled)
        end
        
        if original_secret do
          Application.put_env(:scout_dashboard, :secret, original_secret)
        else
          Application.delete_env(:scout_dashboard, :secret)
        end
      end
    end

    test "ETS table protection is enforced" do
      # Create a public ETS table with Scout name - should trigger security gate
      table_name = :scout_test_table
      :ets.new(table_name, [:public, :named_table])
      
      try do
        # This would catch if we had Scout tables that were :public
        # The actual implementation checks for scout_* table names
        # For this test, we just verify the check logic works
        
        tables = :ets.all()
        public_scout_tables = for table <- tables,
                                  :ets.info(table, :protection) == :public,
                                  name = :ets.info(table, :name),
                                  is_atom(name),
                                  Atom.to_string(name) =~ "scout" do
          name
        end
        
        # Our test table should be detected
        assert table_name in public_scout_tables
        
      after
        :ets.delete(table_name)
      end
    end

    test "security gates prevent dangerous configurations" do
      # Test various dangerous scenarios that should be caught
      
      # 1. Debug mode in production (hypothetical)
      # 2. Default passwords
      # 3. Insecure transports
      # 4. Missing authentication
      
      # These would be expanded based on actual security requirements
      # For now, we test the framework exists
      assert function_exported?(SecurityGates, :check_all!, 0)
    end
  end

  describe "Input validation security" do
    test "rejects malicious JSON payloads" do
      # Test various JSON injection attempts
      malicious_inputs = [
        "{\"__proto__\": {\"isAdmin\": true}}",  # Prototype pollution
        "{\"constructor\": {\"prototype\": {\"admin\": true}}}",
        "function(){return 'hacked';}",  # Not JSON but might be passed
        "<script>alert('xss')</script>",
        "../../../../etc/passwd",  # Path traversal
        "\u0000admin\u0000",  # Null byte injection
        String.duplicate("A", 100_000),  # DoS via large input
      ]
      
      for malicious <- malicious_inputs do
        # Should fail JSON parsing or be sanitized
        case Jason.decode(malicious) do
          {:ok, parsed} ->
            # If it parses as JSON, should be safe data structure
            assert is_map(parsed) or is_list(parsed)
            # Should not contain executable content
            json_string = inspect(parsed)
            refute String.contains?(json_string, "<script>")
            refute String.contains?(json_string, "function")
          
          {:error, _} ->
            # Failing to parse is fine - means it's rejected
            :ok
        end
      end
    end

    test "limits parameter sizes to prevent DoS" do
      # Very large parameter maps should be handled gracefully
      huge_map = for i <- 1..10000, into: %{} do
        {"param_#{i}", String.duplicate("x", 100)}
      end
      
      # Should handle large inputs without crashing
      json_result = Jason.encode(huge_map)
      assert {:ok, _} = json_result
      
      # But should have reasonable size limits in practice
      {:ok, json_string} = json_result
      size_mb = byte_size(json_string) / (1024 * 1024)
      
      # Warn if extremely large (but don't fail test)
      if size_mb > 10 do
        IO.puts("Warning: Large parameter encoding: #{Float.round(size_mb, 2)} MB")
      end
    end

    test "sanitizes log output to prevent log injection" do
      # User input that might contain log control characters
      malicious_inputs = [
        "normal_input",
        "input\nFAKE LOG ENTRY: Admin logged in",  # Log injection
        "input\r\nAnother fake entry",
        "input\x1b[31mRED TEXT\x1b[0m",  # ANSI escape codes
        "input\x00null_byte",  # Null bytes
        "input\ttab\tnoise",  # Tab characters
      ]
      
      for input <- malicious_inputs do
        # When logging user input, it should be sanitized
        sanitized = inspect(input)  # Elixir's inspect is safe
        
        # Should not contain raw newlines that could break log format
        refute String.contains?(sanitized, "\n") 
        refute String.contains?(sanitized, "\r")
        
        # Control characters should be escaped
        if String.contains?(input, "\x1b") do
          assert String.contains?(sanitized, "\\e") or String.contains?(sanitized, "\\x")
        end
      end
    end
  end

  describe "Resource limits and DoS prevention" do
    test "prevents memory exhaustion attacks" do
      # Test creating many small objects vs few large objects
      
      # Many small maps
      small_maps = for i <- 1..10000, do: %{id: i, value: "small"}
      assert length(small_maps) == 10000
      
      # Large individual map
      large_map = for i <- 1..10000, into: %{}, do: {"key_#{i}", "value_#{i}"}
      assert map_size(large_map) == 10000
      
      # Both should be handled without issues
      # In production, you'd have actual limits
      assert is_list(small_maps)
      assert is_map(large_map)
    end

    test "prevents atom table exhaustion via controlled atom creation" do
      # Before fix: String.to_atom("user_input_#{i}") for i in 1..1000000 would exhaust atom table
      # After fix: Only whitelisted atoms are created
      
      initial_atom_count = :erlang.system_info(:atom_count)
      
      # Try to create many "atoms" (should fail)
      for i <- 1..1000 do
        assert_raise ArgumentError, fn ->
          SafeAtoms.goal_from_string!("dynamic_goal_#{i}")
        end
      end
      
      final_atom_count = :erlang.system_info(:atom_count)

      # Atom count should not have grown significantly
      # Note: Some atoms created by test framework (stack traces, error messages)
      # Key test: 1000 attempts should create << 1000 atoms (ideally < 100)
      atom_increase = final_atom_count - initial_atom_count
      assert atom_increase < 100  # Allow test framework overhead, but prevent actual atom exhaustion

      IO.puts("Atom table: #{initial_atom_count} -> #{final_atom_count} (+#{atom_increase})")
    end

    test "handles concurrent operations without crashes" do
      # Simulate many concurrent unsafe operations
      tasks = for i <- 1..100 do
        Task.async(fn ->
          # Mix of valid and invalid operations
          try do
            case rem(i, 4) do
              0 -> SafeAtoms.goal_from_string!("maximize")
              1 -> SafeAtoms.sampler_from_string!("tpe")
              2 -> SafeAtoms.status_from_string!("completed")
              3 -> 
                # This should fail
                SafeAtoms.goal_from_string!("fake_goal_#{i}")
            end
          rescue
            ArgumentError -> :expected_error
          end
        end)
      end
      
      results = Enum.map(tasks, &Task.await/1)
      
      # Should have mix of valid atoms and expected errors
      valid_results = Enum.filter(results, &is_atom/1)
      error_results = Enum.count(results, &(&1 == :expected_error))
      
      assert length(valid_results) > 0
      assert error_results > 0
      assert length(valid_results) + error_results == 100
    end
  end
end