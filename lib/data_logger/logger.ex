defmodule DataLogger.Logger do
  @moduledoc """
  A worker process, created and supervised per destination and per `topic`, also known as a sub-destination.

  The first time `DataLogger.log/2` is called with a given `topic` `DataLogger.Logger` for this `topic` for
  every configured destination are created. They are supervised by a new supervisor, created for the given `topic`.

  A `DataLogger.Logger` process is registered in a pub-sub registry with its `topic`, so when data is sent for this topic,
  every such process is notified and data is *casted* to it in the form of `{:log_data, topic, data}`.

  If the `destination` of a `DataLogger.Logger` is configured to be `send_async: true`, the process
  will be creating a task per *cast* and will be responsible to invoke the `on_error/4`/`on_success/4` of the
  `destination` when the task finishes.
  It will also react when the task is `:DOWN`.
  """

  use GenServer

  alias __MODULE__, as: Mod

  @doc false
  def start_link(topic: topic, name: name, destination: %{module: _, options: _} = destination) do
    GenServer.start_link(Mod, Map.put_new(destination, :topic, topic), name: name)
  end

  @impl true
  def init(%{topic: topic, options: options, module: destination} = state) do
    Registry.register(DataLogger.PubSub, topic, nil)

    initialized_state = %{state | options: destination.initialize(options)}

    initialized_state.options
    |> Map.get(:send_async, false)
    |> if(
      do: {:ok, Map.put_new(initialized_state, :tasks, %{})},
      else: {:ok, initialized_state}
    )
  end

  @impl true
  def handle_cast({:log_data, topic, data}, %{topic: topic, options: options} = state) do
    {:noreply, log_data(options, topic, data, state)}
  end

  @impl true
  def handle_info({_ref, {data, result}}, %{topic: topic} = state) do
    {:noreply, handle_send_data_result(result, topic, data, state)}
  end

  @impl true
  def handle_info({:DOWN, monitored_ref, :process, task_pid, _}, %{tasks: tasks} = state) do
    updated_tasks =
      tasks
      |> Map.get(monitored_ref)
      |> update_tasks(tasks, monitored_ref, task_pid)

    {:noreply, %{state | tasks: updated_tasks}}
  end

  defp log_data(
         %{send_async: true},
         topic,
         data,
         %{module: destination, options: options, tasks: tasks} = state
       ) do
    action = fn ->
      try do
        result = destination.send_data(topic, data, options)

        {data, result}
      rescue
        e -> {data, {:error, e}}
      end
    end

    %Task{pid: pid, ref: ref} = Task.Supervisor.async_nolink(DataLogger.TaskSupervisor, action)

    %{state | tasks: Map.put_new(tasks, ref, pid)}
  end

  defp log_data(
         _,
         topic,
         data,
         %{module: destination, options: options} = state
       ) do
    destination.send_data(topic, data, options)
    |> handle_send_data_result(topic, data, state)
  end

  defp update_tasks(pid, tasks, ref, pid) when is_pid(pid) do
    Map.delete(tasks, ref)
  end

  defp handle_send_data_result(
         result,
         topic,
         data,
         %{module: destination, options: options} = state
       ) do
    case result do
      :ok ->
        destination.on_success(:ok, topic, data, options)
        state

      {:ok, reason} ->
        destination.on_success(reason, topic, data, options)
        state

      {:error, reason} ->
        destination.on_error(reason, topic, data, options)
        state

      {:ok, reason, updated_options} ->
        destination.on_success(reason, topic, data, options)
        %{state | options: updated_options}

      {:error, reason, updated_options} ->
        destination.on_error(reason, topic, data, options)
        %{state | options: updated_options}
    end
  end
end
