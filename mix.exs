defmodule Scout.Umbrella.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.3.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  # Umbrella projects don't define an application
  def application do
    []
  end

  defp deps do
    [
      # Umbrella-level dev tools only
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      # Default setup uses ETS (no DB required)
      setup: ["deps.get"],
      # Optional: run these if you want to use Postgres
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      # Tests use ETS by default
      test: ["test"],
      quality: ["format", "credo --strict"]
    ]
  end
end