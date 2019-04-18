defmodule DataLogger do
  @moduledoc """
  A `DataLogger` can log any data to any configured destination.

  A destination can be configured using the the application configuration:

      config :data_logger,
        destinations: [
          {DestinationImplementation, %{option_one: value_one, option_two: value_two}},
          {AnotherDestinationImplementation, %{option: value}}
        ]

  When such a configuration is defined, chunks of data, represented by Elixir terms
  can be logged to them by using the `DataLogger.log/2` function.

  For example we could have two schemas in a relational database : *green* and *red*.
  We would like to send a list of records to a destination representing this database.
  When we have data that should go to the *green* schema, we would use:

      DataLogger.log(:green, [row1, row2, row3])

  When we want data sent and stored to the *red* schema, we would use:

      DataLogger.log(:red, [row1, row2, row3, row4])

  This way we could have different schemas or tables or clients, etc. and send
  data related to them to a storage defined for them.
  In the *red* and *green* example the configuration would be:

      config :data_logger,
        destinations: [
          {RelationalDBDestination, %{host: "localhost", user: "inflowmatix", password: "secret"}}
        ]

  The destination should be a module, which implements the `DataLogger.Destination` protocol.

  For both the *green* and the *red* data there will be independent supervision tree with a worker
  per destination so the data sent to the *green* destination won't be in the way of the data sent
  to the *red* destination.

  By default the data logged by `DataLogger.log/2` is sent in the worker process
  for the given `prefix` (*green* or *red*) in the above example.
  This can be changed if in the options of the destination `:send_async` is set to `true`:

      config :data_logger,
        destinations: [
          {RelationalDBDestination, %{host: "localhost", user: "inflowmatix", password: "secret", send_async: true}}
        ]

  Now every chunk of data logged with that `prefix` will be sent in its own supervised process.
  The `DataLogger.Destination` behaviour implementation can define `on_error/4` or/and `on_success/4`
  callbacks so the result can be handled.

  Ensuring that the data has been sent and retrying sending it, if needed is a responsibility of the destination
  implementation.
  """

  alias DataLogger.Destination

  @doc """
  This function is the sole entry point of the `DataLogger` application.
  It is used to log/send the `data` passed to it to the configured destinations.

  The `prefix` given can be used to send the data to different sub-destinations of every destination configured.
  """
  @spec log(Destination.prefix(), data :: term()) :: :ok | {:error, reason :: term()}
  def log(prefix, data) do
    prefix
    |> find_or_start_logger_for_preffix()
    |> log_data(prefix, data)
  end

  defp log_data({:ok, sub_pid}, prefix, data) when is_pid(sub_pid) do
    Registry.dispatch(DataLogger.PubSub, prefix, fn subscribers ->
      for {pid, _} <- subscribers do
        GenServer.cast(pid, {:log_data, prefix, data})
      end
    end)
  end

  defp log_data({:error, _} = error, _, _), do: error

  defp find_or_start_logger_for_preffix(prefix) do
    {DataLogger.Registry, {DataLogger.LoggerSupervisor, prefix}}
    |> Registry.whereis_name()
    |> start_or_get_logger_supervisor(prefix)
  end

  defp start_or_get_logger_supervisor(:undefined, prefix) do
    name = {:via, Registry, {DataLogger.Registry, {DataLogger.LoggerSupervisor, prefix}}}

    DataLogger.LoggingSupervisor.start_child(prefix, name)
  end

  defp start_or_get_logger_supervisor(pid, _) when is_pid(pid), do: {:ok, pid}
end
