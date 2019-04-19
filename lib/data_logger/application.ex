defmodule DataLogger.Application do
  @moduledoc """
  The application module of the `DataLogger` application.

  It starts a registry for registered processes, a registry for broadcasting of messages
  and the main dynamic supervisor, responsible for adding new logger sub-trees per sub-destination and destination.

  It could start a task supervisor if `:send_async` is set to true for any configured destination.
  """

  use Application

  @default_destinations []
  @default_config [
    destinations: @default_destinations
  ]

  def start(_type, config \\ @default_config) do
    cfg = Keyword.merge(Application.get_all_env(:data_logger), config)

    destinations =
      cfg
      |> Keyword.get(:destinations, @default_destinations)

    additional_children =
      destinations
      |> Enum.any?(fn {_, options} -> options[:send_async] end)
      |> if(
        do: [
          {Task.Supervisor, name: DataLogger.TaskSupervisor},
          {DataLogger.Supervisor, [cfg]}
        ],
        else: [{DataLogger.Supervisor, [cfg]}]
      )

    children =
      [
        {Registry, keys: :unique, name: DataLogger.Registry},
        {Registry,
         keys: :duplicate, name: DataLogger.PubSub, partitions: System.schedulers_online()}
      ] ++ additional_children

    opts = [strategy: :one_for_all, name: DataLogger.Application.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
