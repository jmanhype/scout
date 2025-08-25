defmodule Scout.Constraints do
  @moduledoc """
  Constraint handling for optimization problems.
  
  Supports:
  - Inequality constraints (g(x) <= 0)
  - Equality constraints (h(x) = 0)
  - Box constraints (parameter bounds)
  - Custom constraint functions
  - Constraint violation metrics
  
  Compatible with multi-objective optimizers like NSGA-II.
  """
  
  @doc """
  Evaluates constraints for given parameters.
  
  Returns a list of constraint values where:
  - Values <= 0 are satisfied
  - Values > 0 are violated
  """
  def evaluate(params, constraint_funcs) when is_list(constraint_funcs) do
    Enum.map(constraint_funcs, fn func ->
      func.(params)
    end)
  end
  
  def evaluate(params, constraint_func) when is_function(constraint_func) do
    constraint_func.(params)
  end
  
  @doc """
  Calculates total constraint violation.
  
  Returns 0 if all constraints are satisfied, otherwise sum of violations.
  """
  def violation(constraint_values) when is_list(constraint_values) do
    constraint_values
    |> Enum.map(&max(&1, 0))
    |> Enum.sum()
  end
  
  def violation(constraint_value) when is_number(constraint_value) do
    max(constraint_value, 0)
  end
  
  @doc """
  Checks if all constraints are satisfied.
  """
  def satisfied?(constraint_values) when is_list(constraint_values) do
    Enum.all?(constraint_values, &(&1 <= 0))
  end
  
  def satisfied?(constraint_value) when is_number(constraint_value) do
    constraint_value <= 0
  end
  
  @doc """
  Creates a box constraint function for parameter bounds.
  """
  def box_constraint(param_name, min, max) do
    fn params ->
      value = Map.get(params, param_name, 0)
      [
        min - value,  # value >= min => min - value <= 0
        value - max   # value <= max => value - max <= 0
      ]
    end
  end
  
  @doc """
  Creates an equality constraint function.
  
  Converts h(x) = 0 to |h(x)| - tolerance <= 0
  """
  def equality_constraint(func, tolerance \\ 1.0e-6) do
    fn params ->
      abs(func.(params)) - tolerance
    end
  end
  
  @doc """
  Creates an inequality constraint function.
  
  Ensures g(x) <= 0 format.
  """
  def inequality_constraint(func) do
    func
  end
  
  @doc """
  Combines multiple constraint functions into one.
  """
  def combine(constraint_funcs) when is_list(constraint_funcs) do
    fn params ->
      constraint_funcs
      |> Enum.flat_map(fn func ->
        result = func.(params)
        if is_list(result), do: result, else: [result]
      end)
    end
  end
  
  @doc """
  Creates a constraint function for a linear constraint: a'x <= b
  """
  def linear_constraint(coefficients, bound) do
    fn params ->
      sum = coefficients
            |> Enum.zip(Map.values(params))
            |> Enum.map(fn {a, x} -> a * x end)
            |> Enum.sum()
      sum - bound
    end
  end
  
  @doc """
  Creates a constraint function for a quadratic constraint: x'Qx + c'x <= b
  """
  def quadratic_constraint(q_matrix, c_vector, bound) do
    fn params ->
      x = Map.values(params)
      
      # Compute x'Qx
      quad_term = x
                  |> Enum.with_index()
                  |> Enum.map(fn {xi, i} ->
                    row = Enum.at(q_matrix, i)
                    xi * (row |> Enum.zip(x) |> Enum.map(fn {qij, xj} -> qij * xj end) |> Enum.sum())
                  end)
                  |> Enum.sum()
      
      # Compute c'x
      linear_term = c_vector
                   |> Enum.zip(x)
                   |> Enum.map(fn {ci, xi} -> ci * xi end)
                   |> Enum.sum()
      
      quad_term + linear_term - bound
    end
  end
  
  @doc """
  Penalty method for handling constraints in single-objective optimization.
  
  Adds a penalty term to the objective function.
  """
  def penalize(objective_value, constraint_values, penalty_coefficient \\ 1000) do
    penalty = violation(constraint_values) * penalty_coefficient
    objective_value + penalty
  end
  
  @doc """
  Augmented Lagrangian method for constraint handling.
  """
  def augmented_lagrangian(objective_value, constraint_values, multipliers, penalty_param) do
    # L(x, λ, ρ) = f(x) + Σ λᵢgᵢ(x) + (ρ/2)Σ max(0, gᵢ(x))²
    
    lagrange_term = multipliers
                   |> Enum.zip(constraint_values)
                   |> Enum.map(fn {lambda, g} -> lambda * g end)
                   |> Enum.sum()
    
    penalty_term = constraint_values
                  |> Enum.map(fn g -> :math.pow(max(0, g), 2) end)
                  |> Enum.sum()
                  |> Kernel.*(penalty_param / 2)
    
    objective_value + lagrange_term + penalty_term
  end
  
  @doc """
  Updates Lagrange multipliers for augmented Lagrangian method.
  """
  def update_multipliers(multipliers, constraint_values, penalty_param, step_size \\ 1.0) do
    multipliers
    |> Enum.zip(constraint_values)
    |> Enum.map(fn {lambda, g} ->
      max(0, lambda + step_size * penalty_param * g)
    end)
  end
  
  @doc """
  Barrier method for handling inequality constraints.
  
  Adds a logarithmic barrier to keep solutions strictly feasible.
  """
  def barrier(objective_value, constraint_values, barrier_param \\ 0.1) do
    # B(x, μ) = f(x) - μ Σ log(-gᵢ(x))
    
    if Enum.any?(constraint_values, &(&1 >= 0)) do
      # Infeasible point
      :infinity
    else
      barrier_term = constraint_values
                    |> Enum.map(fn g -> :math.log(-g) end)
                    |> Enum.sum()
                    |> Kernel.*(barrier_param)
      
      objective_value - barrier_term
    end
  end
  
  @doc """
  Feasibility pump method to find feasible solutions.
  """
  def feasibility_pump(params, constraint_funcs, max_iterations \\ 100) do
    Enum.reduce_while(1..max_iterations, params, fn _i, current_params ->
      violations = evaluate(current_params, constraint_funcs)
      
      if satisfied?(violations) do
        {:halt, {:ok, current_params}}
      else
        # Move towards feasibility
        adjusted = adjust_for_feasibility(current_params, constraint_funcs, violations)
        {:cont, adjusted}
      end
    end)
    |> case do
      {:ok, feasible} -> {:ok, feasible}
      params -> {:error, params}
    end
  end
  
  defp adjust_for_feasibility(params, _constraint_funcs, violations) do
    # Simple gradient-based adjustment
    step_size = 0.1
    total_violation = violation(violations)
    
    if total_violation > 0 do
      # Adjust parameters to reduce violation
      Map.new(params, fn {k, v} ->
        # Random perturbation weighted by violation
        adjustment = :rand.normal() * step_size * :math.sqrt(total_violation)
        {k, v + adjustment}
      end)
    else
      params
    end
  end
  
  @doc """
  Creates a constraint for keeping the sum of parameters equal to a value.
  
  Useful for proportion constraints.
  """
  def sum_constraint(param_names, target_sum, tolerance \\ 1.0e-6) do
    fn params ->
      sum = param_names
            |> Enum.map(&Map.get(params, &1, 0))
            |> Enum.sum()
      abs(sum - target_sum) - tolerance
    end
  end
  
  @doc """
  Creates a constraint for parameter relationships.
  
  E.g., x1 >= x2
  """
  def relationship_constraint(param1, param2, relation \\ :gte) do
    fn params ->
      v1 = Map.get(params, param1, 0)
      v2 = Map.get(params, param2, 0)
      
      case relation do
        :gte -> v2 - v1  # v1 >= v2 => v2 - v1 <= 0
        :gt -> v2 - v1 + 1.0e-6  # v1 > v2
        :lte -> v1 - v2  # v1 <= v2
        :lt -> v1 - v2 + 1.0e-6  # v1 < v2
        :eq -> abs(v1 - v2) - 1.0e-6  # v1 == v2
      end
    end
  end
end