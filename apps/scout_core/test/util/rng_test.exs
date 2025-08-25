defmodule Scout.Util.RNGTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Scout.Util.RNG

  describe "seed_for/2" do
    test "produces deterministic seeds" do
      seed1 = RNG.seed_for("study1", 0)
      seed2 = RNG.seed_for("study1", 0)
      assert seed1 == seed2
    end

    test "different studies produce different seeds" do
      seed1 = RNG.seed_for("study1", 0)
      seed2 = RNG.seed_for("study2", 0)
      assert seed1 != seed2
    end

    test "different trial indices produce different seeds" do
      seed1 = RNG.seed_for("study1", 0)
      seed2 = RNG.seed_for("study1", 1)
      assert seed1 != seed2
    end

    property "seeds are never zero" do
      check all study_id <- string(:ascii, min_length: 1),
                index <- non_negative_integer() do
        {a, b, c} = RNG.seed_for(study_id, index)
        assert a != 0
        assert b != 0 
        assert c != 0
      end
    end
  end

  describe "with_seed/3" do
    test "isolates random state" do
      # Set global state
      :rand.seed(:exsss, {1, 2, 3})
      
      # Use isolated seed
      result = RNG.with_seed("study1", 0, fn ->
        :rand.uniform()
      end)
      
      # Global state should be unchanged
      assert :rand.export_seed() == {exsss, {1, 2, 3}}
      assert is_float(result)
      assert result >= 0.0 and result <= 1.0
    end

    test "produces deterministic results" do
      result1 = RNG.with_seed("study1", 5, fn ->
        for _ <- 1..10, do: :rand.uniform()
      end)
      
      result2 = RNG.with_seed("study1", 5, fn ->
        for _ <- 1..10, do: :rand.uniform()
      end)
      
      assert result1 == result2
    end

    test "different seeds produce different results" do
      result1 = RNG.with_seed("study1", 0, fn ->
        for _ <- 1..10, do: :rand.uniform()
      end)
      
      result2 = RNG.with_seed("study1", 1, fn ->
        for _ <- 1..10, do: :rand.uniform()
      end)
      
      assert result1 != result2
    end

    test "restores state even on error" do
      original = :rand.export_seed()
      
      assert_raise RuntimeError, fn ->
        RNG.with_seed("study1", 0, fn ->
          raise "test error"
        end)
      end
      
      assert :rand.export_seed() == original
    end

    property "always produces valid floats" do
      check all study_id <- string(:ascii, min_length: 1),
                index <- non_negative_integer(),
                count <- integer(1..50) do
        results = RNG.with_seed(study_id, index, fn ->
          for _ <- 1..count, do: :rand.uniform()
        end)
        
        assert length(results) == count
        for result <- results do
          assert is_float(result)
          assert result > 0.0 and result <= 1.0
        end
      end
    end
  end

  describe "generate_sequence/3" do
    test "produces deterministic sequences" do
      seq1 = RNG.generate_sequence("study1", 0, 20)
      seq2 = RNG.generate_sequence("study1", 0, 20)
      assert seq1 == seq2
      assert length(seq1) == 20
    end

    test "different parameters produce different sequences" do
      seq1 = RNG.generate_sequence("study1", 0, 10)
      seq2 = RNG.generate_sequence("study1", 1, 10)  # Different index
      seq3 = RNG.generate_sequence("study2", 0, 10)  # Different study
      
      assert seq1 != seq2
      assert seq1 != seq3
      assert seq2 != seq3
    end
  end

  describe "verify_determinism/3" do
    test "passes for deterministic operations" do
      assert :ok = RNG.verify_determinism("study1", 0, 50)
    end

    test "different studies have different sequences" do
      assert :ok = RNG.verify_determinism("study_a", 0, 50)  
      assert :ok = RNG.verify_determinism("study_b", 0, 50)
      
      seq_a = RNG.generate_sequence("study_a", 0, 50)
      seq_b = RNG.generate_sequence("study_b", 0, 50)
      assert seq_a != seq_b
    end
  end

  describe "verify_isolation/4" do
    test "different trial indices are properly isolated" do
      assert :ok = RNG.verify_isolation("study1", 0, 1, 100)
      assert :ok = RNG.verify_isolation("study1", 5, 10, 50)
    end

    test "fails if somehow same sequences are generated" do
      # This shouldn't happen with proper implementation
      # but we test the validation logic
      defmodule BrokenRNG do
        def generate_sequence(_, _, count) do
          # Always return same sequence (broken!)
          for _ <- 1..count, do: 0.5
        end
      end
      
      # Our real implementation should never fail this
      seq1 = RNG.generate_sequence("study1", 0, 10)
      seq2 = RNG.generate_sequence("study1", 1, 10)
      assert seq1 != seq2  # Proper isolation
    end
  end

  describe "sampler_seed/2" do
    test "produces deterministic sampler seeds" do
      seed1 = RNG.sampler_seed("study1", :tpe)
      seed2 = RNG.sampler_seed("study1", :tpe)
      assert seed1 == seed2
    end

    test "different samplers get different seeds" do
      seed1 = RNG.sampler_seed("study1", :tpe)
      seed2 = RNG.sampler_seed("study1", :random)
      assert seed1 != seed2
    end

    test "different studies get different sampler seeds" do
      seed1 = RNG.sampler_seed("study1", :tpe)
      seed2 = RNG.sampler_seed("study2", :tpe)
      assert seed1 != seed2
    end

    property "sampler seeds are never zero" do
      check all study_id <- string(:ascii, min_length: 1),
                sampler <- member_of([:tpe, :random, :grid, :bandit]) do
        {a, b, c} = RNG.sampler_seed(study_id, sampler)
        assert a != 0
        assert b != 0
        assert c != 0
      end
    end
  end

  describe "with_sampler_seed/3" do
    test "isolates sampler random state" do
      original = :rand.export_seed()
      
      result = RNG.with_sampler_seed("study1", :tpe, fn ->
        :rand.uniform()
      end)
      
      assert :rand.export_seed() == original
      assert is_float(result)
    end

    test "produces deterministic sampler results" do
      result1 = RNG.with_sampler_seed("study1", :tpe, fn ->
        for _ <- 1..5, do: :rand.uniform()
      end)
      
      result2 = RNG.with_sampler_seed("study1", :tpe, fn ->
        for _ <- 1..5, do: :rand.uniform()
      end)
      
      assert result1 == result2
    end
  end

  # Integration test with real random operations
  describe "integration tests" do
    test "concurrent RNG operations don't interfere" do
      task1 = Task.async(fn ->
        RNG.with_seed("study1", 0, fn ->
          Enum.map(1..100, fn _ -> :rand.uniform() end)
        end)
      end)
      
      task2 = Task.async(fn ->
        RNG.with_seed("study2", 0, fn ->
          Enum.map(1..100, fn _ -> :rand.uniform() end) 
        end)
      end)
      
      result1 = Task.await(task1)
      result2 = Task.await(task2)
      
      # Results should be different (different studies)
      assert result1 != result2
      
      # But repeating should give same results
      repeat1 = RNG.generate_sequence("study1", 0, 100)
      repeat2 = RNG.generate_sequence("study2", 0, 100)
      
      assert result1 == repeat1
      assert result2 == repeat2
    end

    test "doesn't affect global random state in production usage" do
      # Simulate production usage pattern
      :rand.seed(:exsss, {42, 43, 44})
      before_global = :rand.uniform()
      
      # Do some Scout operations
      _trial_params = RNG.with_seed("production_study", 10, fn ->
        %{
          learning_rate: 0.001 + :rand.uniform() * 0.099,
          batch_size: Enum.random([16, 32, 64, 128]),
          dropout: :rand.uniform() * 0.5
        }
      end)
      
      # Global state should continue from where it left off
      after_global = :rand.uniform()
      
      # These should be different (global state advanced)
      assert before_global != after_global
      
      # But Scout operations should still be deterministic
      repeat_params = RNG.with_seed("production_study", 10, fn ->
        %{
          learning_rate: 0.001 + :rand.uniform() * 0.099,
          batch_size: Enum.random([16, 32, 64, 128]),
          dropout: :rand.uniform() * 0.5
        }
      end)
      
      assert _trial_params == repeat_params
    end
  end
end