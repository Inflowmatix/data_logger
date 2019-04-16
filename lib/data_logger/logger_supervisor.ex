defmodule DataLogger.LoggerSupervisor do
  @moduledoc """
  Supervisor of a group of `DataLogger.Logger` workers for given `prefix`.
  For every configured destination, there will be a worker.

  For example if we configured a NoSQL destination and a relational destination,
  for given document/schema used as `prefix` a new `DataLogger.LoggerSupervisor` will be
  created and it will be supervising two `DataLogger.Logger` workers.
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
    children =
      config
      |> Keyword.get(:destinations, @default_destinations)
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
