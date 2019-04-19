defmodule DataLogger.Supervisor do
  @moduledoc """
  A `DynamicSupervisor` which adds a new `DataLogger.Destination.Supervisor` and its sub-tree of workers to its
  children, whever a new `topic`, for which data haven't been logged until now is passed to `DataLogger.log/2`.

  Using this, the `DataLogger` application is building its supervision tree lazy and on demand.
  """

  use DynamicSupervisor

  alias __MODULE__, as: Mod

  @default_destinations []
  @default_config [
    destinations: @default_destinations
  ]

  @doc false
  def child_spec(config \\ @default_config), do: Supervisor.Spec.supervisor(Mod, config)

  @doc false
  def start_link(config \\ @default_config),
    do: DynamicSupervisor.start_link(Mod, config, name: Mod)

  @doc false
  def start_child(topic, name) do
    spec = {DataLogger.Destination.Supervisor, topic: topic, name: name}

    DynamicSupervisor.start_child(Mod, spec)
  end

  @impl true
  def init(config),
    do: DynamicSupervisor.init(strategy: :one_for_one, extra_arguments: [config])
end
