defmodule Scout.FixedTrial do
  @moduledoc """
  Fixed trial for testing objective functions with predefined parameters.
  
  Equivalent to Optuna's FixedTrial, allows testing objective functions
  without running a full optimization.
  
  ## Example
  
      def objective(trial) do
        x = Scout.Trial.suggest_float(trial, "x", -1.0, 1.0)
        y = Scout.Trial.suggest_int(trial, "y", -5, 5)
        x + y
      end
      
      # Test with fixed values
      trial = Scout.FixedTrial.new(%{"x" => 1.0, "y" => -1})
      assert objective(trial) == 0.0
      
      trial = Scout.FixedTrial.new(%{"x" => -1.0, "y" => -4})
      assert objective(trial) == -5.0
  """
  
  defstruct [
    :params,
    :user_attrs,
    :system_attrs,
    :intermediate_values,
    :id,
    :study_id
  ]
  
  @doc """
  Creates a new FixedTrial with predefined parameter values.
  """
  def new(params, opts \\ []) do
    %__MODULE__{
      params: params,
      user_attrs: Keyword.get(opts, :user_attrs, %{}),
      system_attrs: Keyword.get(opts, :system_attrs, %{}),
      intermediate_values: Keyword.get(opts, :intermediate_values, %{}),
      id: Keyword.get(opts, :id, "fixed_trial_#{System.unique_integer([:positive])}"),
      study_id: Keyword.get(opts, :study_id, "test_study")
    }
  end
  
  @doc """
  Suggests a float value. Returns the fixed value if available.
  """
  def suggest_float(%__MODULE__{params: params}, name, low, high, opts \\ []) do
    case Map.get(params, name) do
      nil ->
        # Generate default value if not provided
        if Keyword.get(opts, :log, false) do
          :math.sqrt(low * high)  # Geometric mean for log scale
        else
          (low + high) / 2  # Arithmetic mean
        end
      value ->
        # Validate bounds
        if value < low or value > high do
          raise ArgumentError, 
            "Fixed value #{value} for '#{name}' is outside bounds [#{low}, #{high}]"
        end
        value
    end
  end
  
  @doc """
  Suggests an integer value. Returns the fixed value if available.
  """
  def suggest_int(%__MODULE__{params: params}, name, low, high, opts \\ []) do
    case Map.get(params, name) do
      nil ->
        # Generate default value if not provided
        if Keyword.get(opts, :log, false) do
          round(:math.sqrt(low * high))
        else
          div(low + high, 2)
        end
      value ->
        # Validate bounds
        if value < low or value > high do
          raise ArgumentError,
            "Fixed value #{value} for '#{name}' is outside bounds [#{low}, #{high}]"
        end
        round(value)
    end
  end
  
  @doc """
  Suggests a categorical value. Returns the fixed value if available.
  """
  def suggest_categorical(%__MODULE__{params: params}, name, choices) do
    case Map.get(params, name) do
      nil ->
        # Return first choice as default
        hd(choices)
      value ->
        # Validate choice
        if value not in choices do
          raise ArgumentError,
            "Fixed value #{inspect(value)} for '#{name}' is not in choices #{inspect(choices)}"
        end
        value
    end
  end
  
  @doc """
  Reports an intermediate value. For testing, just stores it.
  """
  def report(%__MODULE__{} = trial, value, step) do
    intermediate_values = Map.put(trial.intermediate_values, step, value)
    %{trial | intermediate_values: intermediate_values}
  end
  
  @doc """
  Checks if trial should be pruned. Always returns false for fixed trials.
  """
  def should_prune?(%__MODULE__{}), do: false
  
  @doc """
  Sets a user attribute.
  """
  def set_user_attr(%__MODULE__{} = trial, key, value) do
    user_attrs = Map.put(trial.user_attrs, key, value)
    %{trial | user_attrs: user_attrs}
  end
  
  @doc """
  Gets a user attribute.
  """
  def get_user_attr(%__MODULE__{user_attrs: attrs}, key, default \\ nil) do
    Map.get(attrs, key, default)
  end
  
  @doc """
  Sets a system attribute.
  """
  def set_system_attr(%__MODULE__{} = trial, key, value) do
    system_attrs = Map.put(trial.system_attrs, key, value)
    %{trial | system_attrs: system_attrs}
  end
  
  @doc """
  Gets a system attribute.
  """
  def get_system_attr(%__MODULE__{system_attrs: attrs}, key, default \\ nil) do
    Map.get(attrs, key, default)
  end
  
  @doc """
  Creates a test helper for property-based testing.
  
  Generates random fixed trials within the search space.
  """
  def generate(search_space) do
    params = for {name, spec} <- search_space, into: %{} do
      value = case spec do
        {:uniform, min, max} ->
          min + :rand.uniform() * (max - min)
        {:log_uniform, min, max} ->
          log_min = :math.log(min)
          log_max = :math.log(max)
          :math.exp(log_min + :rand.uniform() * (log_max - log_min))
        {:int, min, max} ->
          min + :rand.uniform(max - min + 1) - 1
        {:choice, choices} ->
          Enum.random(choices)
      end
      
      {name, value}
    end
    
    new(params)
  end
  
  @doc """
  Validates an objective function with multiple test cases.
  
  ## Example
  
      test_cases = [
        {%{"x" => 0, "y" => 0}, 0},
        {%{"x" => 1, "y" => 1}, 2},
        {%{"x" => -1, "y" => 2}, 1}
      ]
      
      Scout.FixedTrial.validate_objective(objective, test_cases)
  """
  def validate_objective(objective_fn, test_cases) do
    results = Enum.map(test_cases, fn {params, expected} ->
      trial = new(params)
      actual = objective_fn.(trial)
      
      %{
        params: params,
        expected: expected,
        actual: actual,
        passed: abs(actual - expected) < 1.0e-6
      }
    end)
    
    all_passed = Enum.all?(results, & &1.passed)
    
    {all_passed, results}
  end
  
  @doc """
  Runs an objective function with a fixed trial and returns detailed results.
  """
  def run(objective_fn, params, opts \\ []) do
    trial = new(params, opts)
    
    start_time = System.monotonic_time(:microsecond)
    
    result = try do
      {:ok, objective_fn.(trial)}
    rescue
      e -> {:error, e}
    end
    
    end_time = System.monotonic_time(:microsecond)
    duration = (end_time - start_time) / 1_000_000  # Convert to seconds
    
    %{
      params: params,
      result: result,
      duration: duration,
      trial: trial
    }
  end
  
  @doc """
  Creates a mock study for testing with fixed trials.
  """
  def mock_study(trials_data) do
    trials = Enum.map(trials_data, fn {params, value} ->
      %Scout.Trial{
        id: "trial_#{System.unique_integer([:positive])}",
        study_id: "mock_study",  # Add required field
        bracket: 0,  # Add required field
        params: params,
        score: value,
        status: :completed
      }
    end)
    
    best_trial = Enum.min_by(trials, & &1.score)
    
    %{
      trials: trials,
      best_trial: best_trial,
      best_params: best_trial.params,
      best_value: best_trial.score,
      n_trials: length(trials)
    }
  end
end