defmodule DataLogger.LoggingSupervisor do
  use DynamicSupervisor

  alias __MODULE__, as: Mod

  def child_spec(_), do: Supervisor.Spec.supervisor(Mod, [])

  def start_link, do: DynamicSupervisor.start_link(Mod, nil, name: Mod)

  def start_child(prefix, name) do
    spec = {DataLogger.LoggerSupervisor, prefix: prefix, name: name}

    DynamicSupervisor.start_child(Mod, spec)
  end

  @impl true
  def init(_), do: DynamicSupervisor.init(strategy: :one_for_one)
end
