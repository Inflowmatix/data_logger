defmodule DataLogger.Application do
  @moduledoc """
  The application module of the `DataLogger` application.

  It starts a registry for registered processes, a registry for broadcasting of messages
  and the main dynamic supervisor, responsible for adding new logger sub-trees per sub-destination and destination.

  It could start a task supervisor if `:send_async` is set to true for any configured destination.
  """

  use Application

  alias DataLogger.LoggingSupervisor

  def start(_type, _args) do
    additional_children =
      :data_logger
      |> Application.get_env(:destinations, [])
      |> Enum.any?(fn {_, options} -> Keyword.get(options, :send_async, false) end)
      |> if(
        do: [{Task.Supervisor, name: DataLogger.TaskSupervisor}, LoggingSupervisor],
        else: [LoggingSupervisor]
      )

    children =
      [
        {Registry, keys: :unique, name: DataLogger.Registry},
        {Registry,
         keys: :duplicate, name: DataLogger.PubSub, partitions: System.schedulers_online()}
      ] ++ additional_children

    opts = [strategy: :one_for_all, name: DataLogger.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
