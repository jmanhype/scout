# Scout - Hyperparameter Optimization for DSPy

<div align="center">
  <img src="https://img.shields.io/badge/DSPy-Optimization-blue" alt="DSPy">
  <img src="https://img.shields.io/badge/Python-3.8+-green" alt="Python">
  <img src="https://img.shields.io/badge/License-MIT-yellow" alt="License">
</div>

## 🚀 Overview

Scout is a powerful hyperparameter optimization framework designed specifically for DSPy (Declarative Self-improving Python) applications. It provides intelligent search algorithms to find optimal configurations for your DSPy programs.

## ✨ Key Features

- **🎯 DSPy-Native**: Built specifically for optimizing DSPy programs
- **🔍 Smart Search**: Advanced hyperparameter search algorithms
- **📊 Study Management**: Organize and track optimization experiments
- **🏗️ CI/CD Ready**: Full Dagger integration for containerized operations
- **🤖 Apollo MCP**: Natural language control via Apollo MCP Server
- **📈 Visualization**: Built-in tools for analyzing optimization results

## 🛠️ Quick Start

```python
from scout import Scout, Study

# Create a new study
study = Study(name="my_optimization")

# Define your search space
search_space = {
    "temperature": [0.1, 0.5, 0.9],
    "max_tokens": [50, 100, 200],
    "model": ["gpt-3.5-turbo", "gpt-4"]
}

# Run optimization
scout = Scout(study=study)
best_params = scout.optimize(
    objective_function=my_dspy_program,
    search_space=search_space,
    n_trials=50
)

print(f"Best parameters: {best_params}")
```

## 🏗️ Apollo MCP Integration

Scout includes full Apollo MCP Server integration for natural language CI/CD operations:

```bash
# Start Dagger session
dagger listen --allow-cors --listen 0.0.0.0:8083

# Run Apollo MCP Server
./apollo-mcp-server

# Now you can use natural language commands!
```

Available Dagger functions:
- `health` - Check project health
- `test` - Run test suite
- `compile` - Compile the project
- `format` - Check code formatting
- `credo` - Run static analysis
- `ci` - Complete CI pipeline

## 📚 Documentation

- [Installation Guide](getting-started/installation.md)
- [Quick Start Tutorial](getting-started/quickstart.md)
- [API Reference](api/scout.md)
- [Apollo MCP Setup](apollo-mcp/setup.md)

## 🤝 Contributing

We welcome contributions! See our [Development Guide](contributing/development.md) to get started.

## 📜 License

Scout is released under the MIT License. See [LICENSE](https://github.com/YOUR_USERNAME/scout/blob/main/LICENSE) for details.

---

<div align="center">
  Built with ❤️ for the DSPy community
</div>