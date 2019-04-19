defmodule DataLogger.LoggerSupervisor do
  @moduledoc """
  Supervisor of a group of `DataLogger.Logger` workers for given `prefix`.
  For every configured destination, there will be a worker.

  For example if we configured a NoSQL destination and a relational destination,
  for given document/schema used as `prefix` a new `DataLogger.LoggerSupervisor` will be
  created and it will be supervising two `DataLogger.Logger` workers.

  If the destinations are specifying prefixes, by including the option `prefix: <prefix>`,
  the supervisor will create and supervise loggers for only these destinations,
  that have prefix which prefixes the `prefix` given to init.
  If the destinations are:

      destinations: [
        {MemoryDestination, %{destination: 1, prefix: :blue}},
        {MemoryDestination, %{destination: 2, prefix: :purple}}
      ]

  And the supervisor is started with `prefix` of `"purple_1"` it will only
  start and supervise a proces for `{MemoryDestination, %{destination: 2, prefix: :purple}}`.

  Using destinations with prefixes we could send part of our data only to subset of the configured
  destinations.
  """

  use Supervisor

  alias __MODULE__, as: Mod

  @default_destinations []
  @default_config [
    destinations: @default_destinations
  ]

  @doc false
  def start_link(config \\ @default_config, prefix: prefix, name: name) do
    Supervisor.start_link(Mod, {prefix, config}, name: name)
  end

  @impl true
  def init({prefix, config}) do
    all_destinations = Keyword.get(config, :destinations, @default_destinations)

    destinations =
      if Enum.any?(all_destinations, fn {_, options} -> Map.has_key?(options, :prefix) end) do
        all_destinations
        |> Enum.filter(fn {_, options} ->
          options[:prefix] &&
            String.starts_with?(to_string(prefix), to_string(options[:prefix]))
        end)
      else
        all_destinations
      end

    children =
      destinations
      |> Enum.map(fn {mod, options} ->
        name =
          {:via, Registry, {DataLogger.Registry, {DataLogger.Logger, {prefix, mod, options}}}}

        %{
          id: {prefix, mod, options},
          start:
            {DataLogger.Logger, :start_link,
             [[prefix: prefix, name: name, destination: %{module: mod, options: options}]]},
          restart: :permanent,
          shutdown: 5000,
          type: :worker
        }
      end)

    Supervisor.init(children, strategy: :one_for_one)
  end
end
