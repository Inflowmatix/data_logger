defmodule DataLogger.Logger do
  @moduledoc """
  A worker process, created and supervised per destination and per `prefix`, also known as sub-destination.

  The first time `DataLogger.log/2` is called with a given `prefix` `DataLogger.Logger` for this `prefix` for
  every configured destination are created. They are supervised by a new supervisor, created for the given `prefix`.

  A `DataLogger.Logger` process is registered in a pub-sub registry with its `prefix`, so when data is send for this prefix,
  every such process is notified and data is *casted* to it in the form of `{:log_data, prefix, data}`.

  If the `destination` of a `DataLogger.Logger` is configured to be `send_async: true`, the process
  will be creating a task per *cast* and will be responsible to to invoke the `on_error/4`/`on_success/4` of the
  `destination` when the task finishes.
  It will also react when the task is down.
  """

  use GenServer

  alias __MODULE__, as: Mod

  @doc false
  def start_link(prefix: prefix, name: name, destination: %{module: _, options: _} = destination) do
    GenServer.start_link(Mod, Map.put_new(destination, :prefix, prefix), name: name)
  end

  @impl true
  def init(%{prefix: prefix, options: options} = state) do
    Registry.register(DataLogger.PubSub, prefix, nil)

    options
    |> Keyword.get(:send_async, false)
    |> if(
      do: {:ok, Map.put_new(state, :tasks, %{})},
      else: {:ok, state}
    )
  end

  @impl true
  def handle_cast({:log_data, prefix, data}, %{prefix: prefix, options: options} = state) do
    new_state =
      options
      |> Keyword.get(:send_async, false)
      |> log_data(prefix, data, state)

    {:noreply, new_state}
  end

  @impl true
  def handle_info(
        {_ref, {data, result}},
        %{module: destination, options: options, prefix: prefix} = state
      ) do
    case result do
      :ok -> Kernel.apply(destination, :on_success, [:ok, prefix, data, options])
      {:ok, reason} -> Kernel.apply(destination, :on_success, [reason, prefix, data, options])
      {:error, reason} -> Kernel.apply(destination, :on_error, [reason, prefix, data, options])
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, monitored_ref, :process, task_pid, _}, %{tasks: tasks} = state) do
    updated_tasks =
      tasks
      |> Map.get(monitored_ref)
      |> update_tasks(tasks, monitored_ref, task_pid)

    {:noreply, %{state | tasks: updated_tasks}}
  end

  defp log_data(false, prefix, data, %{module: destination, options: options} = state) do
    destination
    |> Kernel.apply(:send_data, [prefix, data, options])
    |> case do
      :ok -> Kernel.apply(destination, :on_success, [:ok, prefix, data, options])
      {:ok, reason} -> Kernel.apply(destination, :on_success, [reason, prefix, data, options])
      {:error, reason} -> Kernel.apply(destination, :on_error, [reason, prefix, data, options])
    end

    state
  end

  defp log_data(
         true,
         prefix,
         data,
         %{module: destination, options: options, tasks: tasks} = state
       ) do
    action = fn ->
      try do
        result = Kernel.apply(destination, :send_data, [prefix, data, options])

        {data, result}
      rescue
        e -> {data, {:error, e}}
      end
    end

    %Task{pid: pid, ref: ref} = Task.Supervisor.async_nolink(DataLogger.TaskSupervisor, action)

    %{state | tasks: Map.put_new(tasks, ref, pid)}
  end

  defp update_tasks(pid, tasks, ref, pid) when is_pid(pid) do
    Map.delete(tasks, ref)
  end
end
