defmodule DataLogger.MixProject do
  use Mix.Project

  @version "0.5.0"

  def project do
    [
      app: :data_logger,
      version: @version,
      deps: deps(),
      source_url: "https://github.com/Inflowmatix/data_logger",
      description:
        "A logger that can be used to log any kind of data to remote or local destinations.",
      package: package(),
      docs: docs(),
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
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:mock, "~> 0.3", only: :test},
      {:ex_doc, "~> 0.30", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      name: "data_logger",
      maintainers: ["Inflowmatix"],
      licenses: ["MIT License"],
      links: %{"GitHub" => "https://github.com/Inflowmatix/data_logger"},
      files: ~w(.formatter.exs mix.exs README* config lib)
    ]
  end

  defp docs do
    [
      extras: ["README.md"],
      main: "readme",
      source_ref: "v#{@version}",
      source_url: "https://github.com/Inflowmatix/data_logger"
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
