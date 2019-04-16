defmodule DataLogger.LoggingSupervisor do
  use DynamicSupervisor

  alias __MODULE__, as: Mod

  @default_destinations []
  @default_config [
    destinations: @default_destinations
  ]

  def child_spec(config \\ @default_config), do: Supervisor.Spec.supervisor(Mod, config)

  def start_link(config \\ @default_config),
    do: DynamicSupervisor.start_link(Mod, config, name: Mod)

  def start_child(prefix, name) do
    spec = {DataLogger.LoggerSupervisor, prefix: prefix, name: name}

    DynamicSupervisor.start_child(Mod, spec)
  end

  @impl true
  def init(config),
    do: DynamicSupervisor.init(strategy: :one_for_one, extra_arguments: [config])
end
