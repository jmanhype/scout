defmodule Scout.Math.KDETest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Scout.Math.KDE

  describe "gaussian_kde/1" do
    test "handles empty data" do
      kde_fn = KDE.gaussian_kde([])
      # Should return minimal log-density for any input
      assert kde_fn.(0.0) <= -27.0  # log(eps) ≈ -27.6
      assert kde_fn.(100.0) <= -27.0
    end

    test "handles single point" do
      kde_fn = KDE.gaussian_kde([5.0])
      
      # High probability near the point
      assert kde_fn.(5.0) > kde_fn.(10.0)
      assert kde_fn.(4.999) > kde_fn.(10.0)
      
      # Should never return NaN or infinity
      for x <- [0.0, 5.0, 10.0, 100.0, -100.0] do
        density = kde_fn.(x)
        assert is_float(density)
        assert density == density  # Not NaN
        assert density != :pos_infinity
        assert density != :neg_infinity
      end
    end

    test "handles identical points (degenerate case)" do
      kde_fn = KDE.gaussian_kde([3.0, 3.0, 3.0, 3.0])
      
      # Should act like delta function
      assert kde_fn.(3.0) > kde_fn.(4.0)
      assert kde_fn.(2.9999) > kde_fn.(4.0)
    end

    test "normal case with distinct points" do
      points = [1.0, 2.0, 3.0, 4.0, 5.0]
      kde_fn = KDE.gaussian_kde(points)
      
      # Should give reasonable densities
      density_at_mean = kde_fn.(3.0)  # Center of distribution
      density_at_tail = kde_fn.(10.0)  # Far from data
      
      assert density_at_mean > density_at_tail
      
      # Check numerical stability
      for x <- [-100.0, 0.0, 3.0, 6.0, 100.0] do
        density = kde_fn.(x)
        assert is_float(density)
        assert density == density  # Not NaN
        assert density != :pos_infinity
        assert density != :neg_infinity
        assert density >= -50.0  # Reasonable log-density floor
      end
    end

    property "never returns NaN or infinity" do
      check all points <- list_of(float(), min_length: 0, max_length: 20),
                query_points <- list_of(float(), min_length: 1, max_length: 10) do
        # Filter out NaN/infinity in input
        clean_points = Enum.filter(points, fn x -> 
          is_finite_number(x) and abs(x) < 1000.0
        end)
        clean_queries = Enum.filter(query_points, fn x ->
          is_finite_number(x) and abs(x) < 1000.0  
        end)
        
        if length(clean_queries) > 0 do
          kde_fn = KDE.gaussian_kde(clean_points)
          
          for query <- clean_queries do
            density = kde_fn.(query)
            assert is_float(density)
            assert is_finite_number(density)
            assert density >= -100.0  # Reasonable floor
          end
        end
      end
    end

    property "higher density near data points" do
      check all points <- list_of(float(min: -10.0, max: 10.0), min_length: 2, max_length: 10) do
        unique_points = Enum.uniq(points)
        
        if length(unique_points) >= 2 do
          kde_fn = KDE.gaussian_kde(unique_points)
          
          # Pick a random data point and a far point
          data_point = Enum.random(unique_points)
          far_point = data_point + 20.0  # Far from all data
          
          density_at_data = kde_fn.(data_point)
          density_at_far = kde_fn.(far_point)
          
          # Should be higher density near actual data
          assert density_at_data > density_at_far
        end
      end
    end
  end

  describe "gaussian_kde_with_bandwidth/2" do
    test "respects custom bandwidth" do
      points = [0.0, 1.0, 2.0]
      
      narrow_kde = KDE.gaussian_kde_with_bandwidth(points, 0.1)
      wide_kde = KDE.gaussian_kde_with_bandwidth(points, 2.0)
      
      # Narrow bandwidth should be more peaked
      density_at_data_narrow = narrow_kde.(1.0)
      density_at_data_wide = wide_kde.(1.0)
      
      density_between_narrow = narrow_kde.(0.5)
      density_between_wide = wide_kde.(0.5)
      
      # Wide bandwidth should have more density between points
      assert density_between_wide > density_between_narrow
    end

    test "handles zero bandwidth gracefully" do
      points = [1.0, 2.0, 3.0]
      
      # Should not crash, should use epsilon minimum
      kde_fn = KDE.gaussian_kde_with_bandwidth(points, 0.0)
      
      density = kde_fn.(2.0)
      assert is_float(density)
      assert is_finite_number(density)
    end
  end

  describe "silverman_bandwidth/1" do
    test "returns positive bandwidth for normal data" do
      points = [1.0, 2.0, 3.0, 4.0, 5.0]
      bandwidth = KDE.silverman_bandwidth(points)
      
      assert bandwidth > 0.0
      assert is_finite_number(bandwidth)
    end

    test "handles edge cases" do
      assert KDE.silverman_bandwidth([]) > 0.0
      assert KDE.silverman_bandwidth([5.0]) > 0.0
      assert KDE.silverman_bandwidth([1.0, 1.0, 1.0]) > 0.0  # All same
    end

    test "bandwidth decreases with more data" do
      small_data = [1.0, 2.0, 3.0]
      large_data = Enum.to_list(1..100) |> Enum.map(&(&1/10.0))
      
      bandwidth_small = KDE.silverman_bandwidth(small_data)
      bandwidth_large = KDE.silverman_bandwidth(large_data)
      
      # More data should lead to narrower bandwidth (n^(-1/5) factor)
      assert bandwidth_large < bandwidth_small
    end

    property "always returns positive finite bandwidth" do
      check all points <- list_of(float(min: -100.0, max: 100.0), min_length: 0, max_length: 50) do
        clean_points = Enum.filter(points, &is_finite_number/1)
        bandwidth = KDE.silverman_bandwidth(clean_points)
        
        assert bandwidth > 0.0
        assert is_finite_number(bandwidth)
      end
    end
  end

  describe "exp_density/1" do
    test "converts log densities safely" do
      assert KDE.exp_density(0.0) == 1.0
      assert KDE.exp_density(-1.0) ≈ 0.3678794 within 0.0001
      
      # Very negative log-density should return epsilon
      assert KDE.exp_density(-100.0) == 1.0e-12
      
      # Should handle infinity gracefully
      assert KDE.exp_density(:neg_infinity) == 1.0e-12
    end
  end

  describe "evaluate_multiple/2" do
    test "evaluates KDE at multiple points" do
      points = [1.0, 2.0, 3.0]
      kde_fn = KDE.gaussian_kde(points)
      
      query_points = [0.0, 1.5, 3.0, 5.0]
      densities = KDE.evaluate_multiple(kde_fn, query_points)
      
      assert length(densities) == length(query_points)
      
      for density <- densities do
        assert is_float(density)
        assert is_finite_number(density)
      end
    end
  end

  describe "validate_kde/2" do
    test "validates correct KDE implementation" do
      points = [1.0, 2.0, 3.0, 4.0]
      kde_fn = KDE.gaussian_kde(points)
      test_points = [0.0, 2.5, 5.0]
      
      assert :ok = KDE.validate_kde(kde_fn, test_points)
    end

    test "detects invalid KDE returns" do
      # Mock invalid KDE that returns NaN
      bad_kde = fn _x -> :math.sqrt(-1) end  # Returns NaN
      
      assert {:error, _} = KDE.validate_kde(bad_kde, [1.0])
    end

    test "detects KDE returning infinity" do
      bad_kde = fn _x -> :pos_infinity end
      
      assert {:error, {:infinite_or_nan, :pos_infinity}} = KDE.validate_kde(bad_kde, [1.0])
    end
  end

  # Integration tests
  describe "integration with TPE sampler" do
    test "KDE works for typical TPE use cases" do
      # Simulate good/bad trials for TPE
      good_scores = [0.1, 0.15, 0.12, 0.11, 0.13]  # Low scores (minimizing)
      bad_scores = [0.8, 0.9, 0.85, 0.95, 0.88]    # High scores
      
      good_kde = KDE.gaussian_kde(good_scores)
      bad_kde = KDE.gaussian_kde(bad_scores)
      
      # Test candidate points
      candidates = [0.1, 0.2, 0.5, 0.8, 0.9]
      
      for candidate <- candidates do
        log_good = good_kde.(candidate)
        log_bad = bad_kde.(candidate)
        
        # Should be able to compute ratios safely
        ratio = :math.exp(log_good - log_bad)
        
        assert is_float(ratio)
        assert is_finite_number(ratio)
        assert ratio > 0.0
      end
    end

    test "handles extreme TPE scenarios" do
      # Edge case: very few good trials
      good_scores = [0.1]
      bad_scores = [0.8, 0.9, 0.95]
      
      good_kde = KDE.gaussian_kde(good_scores)
      bad_kde = KDE.gaussian_kde(bad_scores)
      
      # Should not crash and give reasonable results
      ratio_near_good = :math.exp(good_kde.(0.1) - bad_kde.(0.1))
      ratio_near_bad = :math.exp(good_kde.(0.9) - bad_kde.(0.9))
      
      assert is_finite_number(ratio_near_good)
      assert is_finite_number(ratio_near_bad)
      assert ratio_near_good > ratio_near_bad  # Should prefer good region
    end
  end

  # Helper function
  defp is_finite_number(x) when is_number(x) do
    x == x and x != :pos_infinity and x != :neg_infinity
  end
  defp is_finite_number(_), do: false
end