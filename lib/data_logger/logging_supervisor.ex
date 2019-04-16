defmodule DataLogger.LoggingSupervisor do
  @moduledoc """
  A `DynamicSupervisor` which adds a new `DataLogger.LoggingSupervisor` and its sub-tree of workers to its
  children, whnever a new `prefix`, for which data haven't been logged until now is passed to `DataLogger.log/2`.

  Using this, the `DataLogger` application is building its supervision tree lazy and on demand.
  """

  use DynamicSupervisor

  alias __MODULE__, as: Mod

  @doc false
  def child_spec(_), do: Supervisor.Spec.supervisor(Mod, [])

  @doc false
  def start_link, do: DynamicSupervisor.start_link(Mod, nil, name: Mod)

  @doc false
  def start_child(prefix, name) do
    spec = {DataLogger.LoggerSupervisor, prefix: prefix, name: name}

    DynamicSupervisor.start_child(Mod, spec)
  end

  @impl true
  def init(_), do: DynamicSupervisor.init(strategy: :one_for_one)
end
