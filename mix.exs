defmodule DataLogger.MixProject do
  use Mix.Project

  @version "0.2.0"

  def project do
    [
      app: :data_logger,
      deps: deps(),
      description:
        "A toolkit for data mapping and language integrated query for ElixirA logger that can be used to log any kind of data to remote or local destinations",
      package: package(),
      name: "DataLogger",
      start_permanent: Mix.env() == :prod,
      dialyzer: [plt_add_apps: []],
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {DataLogger.Application, []}
    ]
  end

  defp deps do
    [
      {:dialyxir, "~> 1.0.0-rc.6", only: [:dev, :test], runtime: false},
      {:mock, "~> 0.3.0", only: :test}
    ]
  end

  defp package do
    [
      maintainers: ["Inflowmatix"],
      licenses: ["TODO"],
      links: %{"GitHub" => "TODO"},
      files: ~w(.formatter.exs mix.exs README.md)
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
