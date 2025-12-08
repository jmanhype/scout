# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.1] - 2025-12-07

### Added
- Comprehensive documentation guides (GETTING_STARTED.md, API_GUIDE.md)
- Documentation organized in HexDocs with "Guides" and "Reference" sections
- Copy of documentation files in apps/scout_core/ for Hex package inclusion

### Changed
- Updated mix.exs to include all documentation files in Hex package
- Corrected GitHub repository URLs from viable-systems to jmanhype

### Fixed
- Documentation files now properly included in Hex.pm package
- ExDoc configuration uses local paths instead of relative paths

## [0.3.0] - 2025-12-07

### Added
- **90%+ Test Coverage**: Comprehensive test suite covering public API
- **Comprehensive Benchmarks**:
  - Optuna parity validation (Sphere, Rosenbrock, Rastrigin, Ackley)
  - Sampler comparison (TPE, Random, Grid, Bandit)
  - Pruner effectiveness validation
  - Scaling and parallelism benchmarks
- **Production Infrastructure**:
  - Docker and docker-compose for local deployment
  - Kubernetes manifests with auto-scaling
  - Grafana dashboards and Prometheus metrics
  - HTTPS/TLS and secrets management
- **Real-time Dashboard**: Phoenix LiveView monitoring interface
- **Advanced Samplers**: TPE, CMA-ES, NSGA-II, QMC, Grid, Bandit
- **Intelligent Pruners**: Median, Percentile, Hyperband, SuccessiveHalving
- **Distributed Execution**: Oban job queue integration
- **Multi-objective Optimization**: NSGA-II with Pareto dominance

### Changed
- Improved benchmark infrastructure with standard test functions
- Enhanced documentation with usage examples and performance data
- Optimized ETS storage for better performance

### Fixed
- TPE sampler improvements for better convergence
- Pruner configuration and initialization issues
- Random number generation consistency

## [0.2.0] - 2025-11-15

### Added
- Scout.Easy API for Optuna-compatible interface
- Basic samplers: Random, TPE, Grid
- Basic pruners: Median, Percentile
- ETS and PostgreSQL storage adapters
- Telemetry instrumentation

### Changed
- Refactored to umbrella project structure
- Separated scout_core and scout_dashboard

## [0.1.0] - 2025-10-01

### Added
- Initial release
- Core optimization framework
- Study and trial management
- Basic random sampling

[0.3.1]: https://github.com/jmanhype/scout/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/jmanhype/scout/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/jmanhype/scout/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/jmanhype/scout/releases/tag/v0.1.0
