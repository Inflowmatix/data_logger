defmodule DataLogger.Destination do
  @moduledoc """
  A behaviour, representing a destination.

  The mandatory callback to implement is `DataLogger.Destination.send_data/3`.
  An implementation should handle errors and retries by using the optional callbacks
  `DataLogger.Destination.on_error/4` or/and `DataLogger.Destination.on_success/4`.
  These functions are called with the result of the call to the `DataLogger.Destination.send_data/4` function.
  Also an implementation can have some custom initialization, using the optional callback `DataLogger.Destination.init/1` which
  gets the configured options from the config and can return modified options.
  By default it returns what is passed to it.

  A possible implementation should look like this:

      defmodule RelationalDBDestination do
        use DataLogger.Destination

        @impl true
        def send_data(prefix, data, options) do
          connection = ConnectionToDBImpl.connect(options)

          query_to_insert_data = transform_data_to_query(prefix, data)

          case ConnectionToDBImpl.execute(connection, query_to_insert_data, data) do
            :ok -> :ok
            {:error, reason} -> {:error, reason}
          end
        end
      end

  The implementation can also define the `DataLogger.Destination.on_error/4` function and retry on error or
  log some message. The default implementations of the `DataLogger.Destination.on_error/4` and `DataLogger.Destination.on_success/4` callbacks, do nothing.

  The above example implementation can be configured in the application configuration like this:

      config :data_logger,
        destinations: [
          {RelationalDBDestination, [host: "localhost", user: "inflowmatix", password: "secret", send_async: true]}
        ]
  """

  @type prefix :: atom() | String.t()
  @type options :: map()
  @type send_result ::
          :ok
          | {:ok, result :: term()}
          | {:error, reason :: term()}
          | {:ok, result :: term(), options()}
          | {:error, reason :: term(), options()}

  @callback send_data(prefix(), data :: term(), options()) :: send_result()

  @callback initialize(options()) :: options()

  @callback on_error(error :: term(), prefix(), data :: term(), options()) :: :ok
  @callback on_success(result :: term(), prefix(), data :: term(), options()) :: :ok

  @optional_callbacks initialize: 1,
                      on_error: 4,
                      on_success: 4

  @doc false
  defmacro __using__(_) do
    quote do
      @behaviour DataLogger.Destination

      @doc false
      def initialize(options), do: options

      @doc false
      def on_error(_, _, _, _), do: :ok

      @doc false
      def on_success(_, _, _, _), do: :ok

      defoverridable initialize: 1, on_error: 4, on_success: 4
    end
  end
end
