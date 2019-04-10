use Mix.Config

config :data_logger,
  destinations: [
    {DataLogger.MemoryDestination, [destination: 1]},
    {DataLogger.MemoryDestination, [destination: 2]}
  ]
