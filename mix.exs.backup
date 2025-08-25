defmodule Scout.MixProject do
  use Mix.Project

  def project do
    [
      app: :scout,
      version: "0.6.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      aliases: aliases()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Scout.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Database & Jobs
      {:ecto_sql, "~> 3.10"},
      {:postgrex, ">= 0.0.0"},
      {:oban, "~> 2.17"},
      
      # Dashboard
      {:phoenix, "~> 1.7"},
      {:phoenix_live_view, "~> 0.20"},
      {:phoenix_html, "~> 4.0"},
      {:phoenix_view, "~> 2.0"},
      {:plug_cowboy, "~> 2.7"},
      {:bandit, "~> 1.5"},
      {:jason, "~> 1.4"},
      {:telemetry, "~> 1.2"},
      
      # Development & Testing
      {:stream_data, "~> 1.0", only: [:test]},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: [:test]},
      {:mox, "~> 1.0", only: [:test]}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      
      # Quality assurance
      quality: ["format", "credo --strict", "dialyzer", "sobelow -i Config.Secrets --exit"],
      
      # CI pipeline
      ci: [
        "compile --warnings-as-errors",
        "test --warnings-as-errors --cover",
        "quality"
      ],
      
      # Test with coverage
      test_coverage: ["coveralls.html"],
      test_ci: ["coveralls.json"]
    ]
  end
end