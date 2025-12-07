defmodule ScoutCore.MixProject do
  use Mix.Project

  def project do
    [
      app: :scout_core,  # Directory name must match in umbrella
      version: "0.3.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),

      # Test coverage
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.json": :test
      ],

      # Hex publishing
      description: description(),
      package: package(),
      docs: docs(),
      source_url: "https://github.com/viable-systems/scout",
      homepage_url: "https://github.com/viable-systems/scout"
    ]
  end

  defp description do
    """
    Production-ready hyperparameter optimization for Elixir with >99% Optuna parity.
    Leverages BEAM fault tolerance, real-time dashboards, and native distributed computing.
    """
  end

  defp package do
    [
      name: "scout",
      files: ~w(lib priv .formatter.exs mix.exs README* LICENSE* CHANGELOG*),
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/viable-systems/scout",
        "Docs" => "https://hexdocs.pm/scout"
      },
      maintainers: ["Viable Systems"]
    ]
  end

  defp docs do
    [
      main: "Scout",
      extras: ["README.md"],
      source_ref: "v0.3.0",
      source_url: "https://github.com/viable-systems/scout"
    ]
  end

  def application do
    [
      extra_applications: [:logger, :runtime_tools],
      mod: {Scout.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Core dependencies ONLY - no Phoenix!
      {:ecto_sql, "~> 3.10"},
      {:postgrex, ">= 0.0.0"},
      {:oban, "~> 2.15"},
      {:telemetry, "~> 1.2"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:jason, "~> 1.2"},
      
      # Dev/Test
      {:ex_doc, "~> 0.27", only: :dev, runtime: false},
      {:excoveralls, "~> 0.18", only: :test, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.3", only: [:dev], runtime: false}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end
end