defmodule ScoutCore.MixProject do
  use Mix.Project

  def project do
    [
      app: :scout_core,
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

      # Hex package metadata
      description: description(),
      package: package(),
      name: "Scout",
      source_url: "https://github.com/your-org/scout",
      homepage_url: "https://github.com/your-org/scout",
      docs: docs()
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

  defp description do
    """
    Production-ready hyperparameter optimization for Elixir with >99% Optuna feature parity.
    Leverages BEAM's fault tolerance, real-time dashboards, and native distributed computing
    for ML and LLM model tuning.
    """
  end

  defp package do
    [
      name: "scout",
      files: ~w(lib priv .formatter.exs mix.exs README* LICENSE* CHANGELOG*),
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/your-org/scout",
        "Docs" => "https://hexdocs.pm/scout"
      },
      maintainers: ["Scout Contributors"]
    ]
  end

  defp docs do
    [
      main: "Scout",
      extras: ["README.md", "LICENSE"],
      source_ref: "v0.3.0",
      formatters: ["html"]
    ]
  end
end