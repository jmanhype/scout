# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0] - 2025-01-06

### Added
- Production-ready hyperparameter optimization framework
- >99% feature parity with Optuna
- 23 sampling algorithms (TPE, CMA-ES, NSGA-II, QMC, GP-BO, Random, Grid)
- 7 pruning strategies (Median, Percentile, Patient, Threshold, Wilcoxon, SuccessiveHalving, Hyperband)
- Multi-objective optimization with NSGA-II and MOTPE
- PostgreSQL persistence layer with Ecto
- Distributed execution via Oban job queue
- Comprehensive telemetry and observability
- Phoenix LiveView dashboard integration (separate package)
- Native Axon neural network integration
- Deterministic seeding with SHA256-based RNG
- Fault-tolerant study execution with supervision trees
- Hot code reloading support

### Changed
- Refactored to umbrella application structure (scout_core + scout_dashboard)
- Separated core library from UI components
- Updated Ecto configuration for proper OTP app naming
- Improved schema validation with graceful degradation

### Fixed
- Compile-time schema loading (now runtime with fallbacks)
- Module namespace conflicts in umbrella structure
- Ecto Repo configuration for umbrella apps
- Application startup dependencies

## [0.2.0] - 2024-08-25

### Added
- Initial public release
- Basic TPE implementation
- Local execution support
- ETS-based storage

### Changed
- Migrated from monolithic structure to modular design

## [0.1.0] - 2024-08-01

### Added
- Initial development version
- Proof of concept implementation
- Core optimization algorithms

[0.3.0]: https://github.com/viable-systems/scout/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/viable-systems/scout/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/viable-systems/scout/releases/tag/v0.1.0
