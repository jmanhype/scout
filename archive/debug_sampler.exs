#!/usr/bin/env elixir

# DEBUG: Test Scout sampler directly

defmodule SamplerDebug do
  def test_search_space() do
    IO.puts("=== Testing SearchSpace.sample directly ===")
    
    spec = %{
      learning_rate: {:log_uniform, 0.001, 0.3},
      max_depth: {:int, 3, 10},
      n_estimators: {:int, 50, 300}
    }
    
    IO.puts("Spec: #{inspect(spec)}")
    
    try do
      params = Scout.SearchSpace.sample(spec)
      IO.puts("Sampled params: #{inspect(params)}")
    rescue
      error ->
        IO.puts("Error sampling: #{inspect(error)}")
    end
  end
  
  def test_random_sampler() do
    IO.puts("\n=== Testing RandomSearch.next ===")
    
    space_fun = fn _ix -> 
      %{
        x: {:uniform, -1.0, 1.0},
        y: {:uniform, -1.0, 1.0}
      }
    end
    
    state = Scout.Sampler.RandomSearch.init(%{})
    
    try do
      {params, new_state} = Scout.Sampler.RandomSearch.next(space_fun, 1, [], state)
      IO.puts("Random params: #{inspect(params)}")
      IO.puts("New state: #{inspect(new_state)}")
    rescue
      error ->
        IO.puts("Error in RandomSearch: #{inspect(error)}")
    end
  end
  
  def test_tpe_sampler() do
    IO.puts("\n=== Testing TPE.next with no history ===")
    
    space_fun = fn _ix -> 
      %{
        x: {:uniform, -1.0, 1.0},
        y: {:uniform, -1.0, 1.0}
      }
    end
    
    state = Scout.Sampler.TPE.init(%{min_obs: 10, gamma: 0.25, goal: :maximize})
    IO.puts("TPE state: #{inspect(state)}")
    
    try do
      {params, new_state} = Scout.Sampler.TPE.next(space_fun, 1, [], state)
      IO.puts("TPE params: #{inspect(params)}")
      IO.puts("Should fallback to random since history is empty")
    rescue
      error ->
        IO.puts("Error in TPE: #{inspect(error)}")
        IO.puts("Stacktrace: #{Exception.format(:error, error, __STACKTRACE__)}")
    end
  end
  
  def run_all_tests() do
    IO.puts("🔍 DEBUGGING SCOUT SAMPLER ISSUES")
    IO.puts(String.duplicate("=", 50))
    
    test_search_space()
    test_random_sampler()
    test_tpe_sampler()
    
    IO.puts("\n🎯 This shows exactly where the gap is!")
  end
end

SamplerDebug.run_all_tests()