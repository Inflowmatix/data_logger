use Mix.Config

config :data_logger,
  destinations: [
    {DataLogger.Testing.MemoryDestination, %{destination: 1}},
    {DataLogger.Testing.MemoryDestination, %{destination: 2}}
  ]
