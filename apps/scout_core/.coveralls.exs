# ExCoveralls configuration for Scout
# Enforces 100% test coverage

coverage_options: [
  # Minimum coverage threshold - fail CI if below this
  minimum_coverage: 100.0,

  # Files to exclude from coverage (experimental/deprecated modules)
  skip_files: [
    # Legacy/experimental modules not in public API
    "lib/store/ets_hardened.ex",       # Experimental, not used in production
    "lib/sampler/multivariate_tpe_v2.ex",  # V2 experimental
    "lib/sampler/optimized_correlated_tpe.ex",  # Experimental

    # Generated files
    "test/support/**/*.ex"
  ],

  # Coverage per-file details
  treat_no_relevant_lines_as_covered: true,

  # Output formats
  output_dir: "cover/",

  # Stop on threshold failure
  stop_on_failure: true
]
