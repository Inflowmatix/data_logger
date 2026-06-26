defmodule DataLogger.Destination.Supervisor do
  @moduledoc """
  Supervisor of a group of `DataLogger.Destination.Controller` workers for given `topic`.
  For every configured destination, there will be a worker (unless prefixes are used).

  For example if we configured a NoSQL destination and a relational destination,
  for given document/schema used as `topic` a new `DataLogger.Destination.Supervisor` will be
  created and it will be supervising two `DataLogger.Destination.Controller` workers.

  If the destinations are specifying prefixes, by including the option `prefix: <prefix>`,
  the supervisor will create and supervise loggers for only these destinations,
  that have prefix which prefixes the `topic` given to start_link.
  If the destinations are:

      destinations: [
        {MemoryDestination, %{destination: 1, prefix: :blue}},
        {MemoryDestination, %{destination: 2, prefix: :purple}}
      ]

  And the supervisor is started with `topic` of `"purple_1"` it will only
  start and supervise a proces for `{MemoryDestination, %{destination: 2, prefix: :purple}}`.

  Using destinations with prefixes we could send part of our data only to subset of the configured
  destinations.
  """

  use Supervisor

  alias __MODULE__, as: Mod

  alias DataLogger.Destination.Controller

  @default_destinations []
  @default_config [
    destinations: @default_destinations
  ]

  @doc false
  def start_link(config \\ @default_config, topic: topic, name: name) do
    Supervisor.start_link(Mod, {topic, config}, name: name)
  end

  @doc false
  # Started on demand by `DataLogger.Supervisor` (a `DynamicSupervisor`) per topic.
  # `restart: :transient` so that when this supervisor auto-shuts-down after its
  # (significant) idle controllers stop `:normal`, the `DynamicSupervisor` does NOT
  # restart it. Its registry entry is then released and the next `DataLogger.log/2`
  # for the topic recreates the whole sub-tree (and re-subscribes the controllers).
  def child_spec(opts) do
    %{
      id: {__MODULE__, Keyword.get(opts, :topic)},
      start: {__MODULE__, :start_link, [opts]},
      type: :supervisor,
      restart: :transient
    }
  end

  @impl true
  def init({topic, config}) do
    all_destinations = Keyword.get(config, :destinations, @default_destinations)

    destinations =
      if Enum.any?(all_destinations, fn {_, options} -> Map.has_key?(options, :prefix) end) do
        all_destinations
        |> Enum.filter(fn {_, options} ->
          options[:prefix] && String.starts_with?(to_string(topic), to_string(options[:prefix]))
        end)
      else
        all_destinations
      end

    children =
      destinations
      |> Enum.map(fn {mod, options} ->
        name = {:via, Registry, {DataLogger.Registry, {Controller, {topic, mod, options}}}}

        %{
          id: {topic, mod, options},
          start:
            {Controller, :start_link,
             [[topic: topic, name: name, destination: %{module: mod, options: options}]]},
          restart: :transient,
          # Marked significant so that when every controller for this topic stops
          # `:normal` (after its inactivity timeout), `auto_shutdown: :all_significant`
          # tears this supervisor down too — clearing its registry entry so the next
          # `DataLogger.log/2` recreates and re-subscribes the controllers. Without
          # this, an idle `:transient` controller stays dead while the supervisor
          # lingers, and `DataLogger.log/2` dispatches to zero subscribers (silent drop).
          significant: true,
          shutdown: 5000,
          type: :worker
        }
      end)

    Supervisor.init(children, strategy: :one_for_one, auto_shutdown: :all_significant)
  end
end
