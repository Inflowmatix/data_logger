defmodule DataLogger.Testing.MemoryDestination do
  use DataLogger.Destination

  alias __MODULE__

  def start_link(state \\ []) do
    Agent.start_link(fn -> state end)
  end

  def child_spec(arg) do
    %{
      id: MemoryDestination,
      start: {MemoryDestination, :start_link, [arg]}
    }
  end

  @impl true
  def send_data(prefix, {pid, data}, options) when is_pid(pid) do
    Agent.update(pid, fn current ->
      [%{prefix: prefix, data: data, options: options} | current]
    end)
  end

  def get_current_state(pid, min_expected_data_size \\ 0) when is_pid(pid) do
    data = Agent.get(pid, & &1)

    if Enum.count(data) < min_expected_data_size do
      Process.sleep(200)
      get_current_state(pid, min_expected_data_size)
    else
      data
    end
  end

  def get_data_per_topic(pid, min_expected_data_size \\ 0) do
    pid
    |> get_current_state(min_expected_data_size)
    |> Enum.reduce(%{}, fn %{prefix: prefix, data: data, options: options}, acc ->
      Map.update(acc, prefix, [{data, options}], &[{data, options} | &1])
    end)
  end

  def with_async_destination(fun) when is_function(fun) do
    destinations = Application.get_env(:data_logger, :destinations, [])
    :ok = Application.stop(:data_logger)

    try do
      async_destination = {__MODULE__, [destination: 3, send_async: true]}
      Application.put_env(:data_logger, :destinations, [async_destination | destinations])

      {:ok, [:data_logger]} = Application.ensure_all_started(:data_logger)

      fun.()
    after
      Application.put_env(:data_logger, :destinations, destinations)
    end
  end
end
