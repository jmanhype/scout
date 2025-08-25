# DSPy Integration

Scout is designed specifically for optimizing DSPy (Declarative Self-improving Python) programs, providing seamless integration and specialized features for prompt engineering and LLM optimization.

## What is DSPy?

DSPy is a framework for algorithmically optimizing LM prompts and weights. Instead of manually crafting prompts, DSPy programs define the task and metrics, then automatically learn effective prompts through optimization.

## Scout's DSPy-Specific Features

### Prompt Template Optimization

Scout can optimize DSPy prompt templates directly:

```elixir
# Optimize DSPy prompt templates
result = Scout.Easy.optimize(
  fn params ->
    # Configure DSPy program with Scout-suggested parameters
    dspy_config = %{
      temperature: params.temperature,
      max_tokens: params.max_tokens,
      prompt_style: params.prompt_style,
      few_shot_examples: params.n_examples,
      chain_of_thought: params.use_cot
    }
    
    # Run DSPy program and return metric
    accuracy = DSPy.evaluate(
      program: MyDSPyProgram,
      config: dspy_config,
      dataset: validation_set
    )
    
    accuracy
  end,
  %{
    temperature: {:uniform, 0.0, 2.0},
    max_tokens: {:int, 50, 500},
    prompt_style: {:choice, ["direct", "instructional", "conversational"]},
    n_examples: {:int, 0, 10},
    use_cot: {:choice, [true, false]}
  },
  n_trials: 100
)
```

### LLM Model Selection

Optimize across different language models:

```elixir
search_space = %{
  model: {:choice, ["gpt-3.5-turbo", "gpt-4", "claude-2", "llama-2-70b"]},
  temperature: {:uniform, 0, 1.5},
  top_p: {:uniform, 0.5, 1.0},
  frequency_penalty: {:uniform, 0, 2},
  presence_penalty: {:uniform, 0, 2}
}

result = Scout.Easy.optimize(
  fn params ->
    response = LLM.complete(
      model: params.model,
      temperature: params.temperature,
      top_p: params.top_p,
      frequency_penalty: params.frequency_penalty,
      presence_penalty: params.presence_penalty,
      prompt: your_prompt
    )
    
    # Evaluate response quality
    score_response(response)
  end,
  search_space,
  n_trials: 50
)
```

### Prompt Chaining Optimization

Optimize multi-step prompt chains:

```elixir
# Optimize a chain of prompts
result = Scout.Easy.optimize(
  fn params ->
    # Step 1: Initial analysis
    step1_result = DSPy.execute(
      AnalysisModule,
      temperature: params.step1_temp,
      prompt_template: params.step1_template
    )
    
    # Step 2: Reasoning
    step2_result = DSPy.execute(
      ReasoningModule,
      input: step1_result,
      temperature: params.step2_temp,
      use_examples: params.step2_examples
    )
    
    # Step 3: Final answer
    final_result = DSPy.execute(
      AnswerModule,
      input: step2_result,
      temperature: params.step3_temp,
      format: params.output_format
    )
    
    # Evaluate the complete chain
    evaluate_chain_output(final_result)
  end,
  %{
    # Optimize each step independently
    step1_temp: {:uniform, 0, 1},
    step1_template: {:choice, ["analytical", "exploratory"]},
    step2_temp: {:uniform, 0, 1},
    step2_examples: {:int, 0, 5},
    step3_temp: {:uniform, 0, 0.5},
    output_format: {:choice, ["json", "markdown", "plain"]}
  },
  n_trials: 100
)
```

## Integration Patterns

### Direct DSPy Module Integration

```elixir
defmodule ScoutDSPy do
  def optimize_dspy_module(module, dataset, config \\ %{}) do
    Scout.Easy.optimize(
      fn params ->
        # Update DSPy module with Scout parameters
        module
        |> DSPy.configure(params)
        |> DSPy.compile(dataset.train)
        |> DSPy.evaluate(dataset.validation)
      end,
      build_search_space(module),
      Keyword.merge([n_trials: 100, dashboard: true], config)
    )
  end
  
  defp build_search_space(module) do
    # Automatically construct search space from DSPy module
    %{
      temperature: {:uniform, 0, 2},
      max_tokens: {:int, 10, 1000},
      examples_per_class: {:int, 1, 10},
      prompt_style: {:choice, module.supported_styles()},
      use_chain_of_thought: {:choice, [true, false]}
    }
  end
end
```

### Few-Shot Learning Optimization

```elixir
# Optimize few-shot example selection
result = Scout.Easy.optimize(
  fn params ->
    # Select examples based on Scout's suggestions
    examples = select_examples(
      n_per_class: params.n_examples,
      selection_strategy: params.strategy,
      diversity_weight: params.diversity
    )
    
    # Configure DSPy with selected examples
    dspy_program = DSPy.compile(
      MyProgram,
      examples: examples,
      temperature: params.temperature
    )
    
    # Evaluate on validation set
    DSPy.evaluate(dspy_program, validation_data)
  end,
  %{
    n_examples: {:int, 1, 20},
    strategy: {:choice, ["random", "diverse", "similar", "hard"]},
    diversity: {:uniform, 0, 1},
    temperature: {:uniform, 0, 1}
  },
  n_trials: 50
)
```

### Retrieval-Augmented Generation (RAG)

```elixir
# Optimize RAG pipeline parameters
result = Scout.Easy.optimize(
  fn params ->
    # Configure retrieval
    retriever = Retriever.new(
      k: params.n_documents,
      similarity_threshold: params.threshold,
      reranking: params.use_reranking
    )
    
    # Configure generation
    generator = DSPy.build(
      GeneratorModule,
      temperature: params.gen_temperature,
      max_tokens: params.max_tokens
    )
    
    # Build RAG pipeline
    rag_pipeline = DSPy.chain([retriever, generator])
    
    # Evaluate end-to-end performance
    evaluate_rag(rag_pipeline, test_queries)
  end,
  %{
    n_documents: {:int, 1, 10},
    threshold: {:uniform, 0.5, 0.95},
    use_reranking: {:choice, [true, false]},
    gen_temperature: {:uniform, 0, 1},
    max_tokens: {:int, 50, 500}
  },
  n_trials: 100
)
```

## Best Practices

### 1. Metric Design
Design metrics that capture both accuracy and efficiency:

```elixir
def evaluate_dspy_program(program, params, data) do
  results = DSPy.run(program, data, params)
  
  accuracy = calculate_accuracy(results)
  latency = calculate_avg_latency(results)
  token_cost = calculate_token_usage(results)
  
  # Composite metric
  accuracy - (0.001 * latency) - (0.0001 * token_cost)
end
```

### 2. Handling Stochasticity
LLMs are stochastic, so use multiple evaluations:

```elixir
def robust_evaluate(params) do
  # Run multiple times and average
  scores = for _ <- 1..5 do
    DSPy.evaluate(program, params)
  end
  
  Enum.mean(scores)
end
```

### 3. Cost-Aware Optimization
Consider API costs during optimization:

```elixir
search_space = %{
  model: {:choice, [
    {"gpt-3.5-turbo", cost: 0.002},
    {"gpt-4", cost: 0.03},
    {"claude-2", cost: 0.01}
  ]},
  max_tokens: {:int, 50, 500}
}

# Include cost in objective
objective = fn params ->
  performance = evaluate_model(params)
  cost = params.model.cost * params.max_tokens / 1000
  
  # Maximize performance per dollar
  performance / (cost + 0.001)
end
```

## Advanced DSPy Features

### Signature Optimization
Optimize DSPy signatures dynamically:

```elixir
# Optimize the signature itself
result = Scout.Easy.optimize(
  fn params ->
    signature = DSPy.Signature.new(
      input_fields: params.input_fields,
      output_fields: params.output_fields,
      instructions: params.instructions
    )
    
    program = DSPy.compile(MyModule, signature: signature)
    DSPy.evaluate(program, data)
  end,
  %{
    input_fields: {:choice, [
      ["question"],
      ["question", "context"],
      ["question", "context", "examples"]
    ]},
    output_fields: {:choice, [
      ["answer"],
      ["answer", "confidence"],
      ["answer", "reasoning", "confidence"]
    ]},
    instructions: {:choice, [
      "Be concise",
      "Think step by step",
      "Provide detailed explanation"
    ]}
  },
  n_trials: 50
)
```

### Compiler Strategy Optimization
```elixir
# Optimize DSPy compiler strategies
result = Scout.Easy.optimize(
  fn params ->
    compiled = DSPy.compile(
      program,
      strategy: params.compiler,
      bootstrap_n: params.bootstrap_n,
      max_iterations: params.max_iter
    )
    
    DSPy.evaluate(compiled, validation_set)
  end,
  %{
    compiler: {:choice, ["bootstrap", "bootstrap_fs", "mipro"]},
    bootstrap_n: {:int, 4, 16},
    max_iter: {:int, 5, 20}
  },
  n_trials: 30
)
```

## Integration Examples

Find complete DSPy integration examples in:
- `examples/dspy_optimization.exs`
- `examples/prompt_engineering.exs`
- `examples/rag_pipeline.exs`

## Next Steps

- Learn about [Hyperparameter Optimization](hyperparameter-optimization.md)
- Explore [Study Management](study-management.md)
- Review [API Reference](../api/scout.md)