defmodule DataLogger.Destination.ControllerTest do
  use ExUnit.Case

  alias DataLogger.Testing.MemoryDestination
  alias DataLogger.Destination.Controller

  import Mock
  import ExUnit.CaptureLog

  defmodule BlueTestDestination do
    use DataLogger.Destination

    def send_data(_, _, _), do: :ok
  end

  defmodule RedTestDestination do
    use DataLogger.Destination

    def send_data(_, _, _), do: :ok
  end

  def wait_for_task(worker_pid) do
    case :sys.get_state(worker_pid) do
      %{tasks: m} when map_size(m) == 0 ->
        :ok

      _ ->
        Process.sleep(200)
        wait_for_task(worker_pid)
    end
  end

  setup do
    {:ok, destination_pid} = start_supervised(MemoryDestination)

    {:ok, green_worker_pid} =
      Controller.start_link(
        topic: :green,
        name: :green_test_worker,
        destination: %{module: MemoryDestination, options: %{}}
      )

    %{
      destination_pid: destination_pid,
      green_worker: green_worker_pid
    }
  end

  test "casting log_data sends the data to the configured destination", %{
    destination_pid: destination_pid,
    green_worker: green_worker_pid
  } do
    :ok = GenServer.cast(green_worker_pid, {:log_data, :green, {destination_pid, :test_event}})

    data =
      destination_pid
      |> MemoryDestination.get_data_per_topic(1)

    assert Map.keys(data) == [:green]
    assert data.green == [test_event: %{}]
  end

  test "sending with the wrong topic doesn't work", %{
    destination_pid: destination_pid,
    green_worker: green_worker_pid
  } do
    Process.flag(:trap_exit, true)

    capture_log(fn ->
      GenServer.cast(green_worker_pid, {:log_data, :blue, {destination_pid, :test_event}})

      assert_receive({:EXIT, ^green_worker_pid, {:function_clause, _}})
    end)
  end

  test "the destination on_success/4 function is called on success and on_error/4 on error" do
    with_mock(BlueTestDestination,
      on_success: fn
        :ok, :blue, :test_event, %{} -> :ok
        any, :blue, :another_event, %{} -> any
      end,
      on_error: fn
        :test_reason, :blue, :error_event, %{} -> :error
      end,
      initialize: fn options -> options end,
      send_data: fn
        _, :test_event, _ -> :ok
        _, :another_event, _ -> {:ok, :good_show}
        _, :error_event, _ -> {:error, :test_reason}
      end
    ) do
      {:ok, worker_pid} =
        Controller.start_link(
          topic: :blue,
          name: :blue_test_worker,
          destination: %{module: BlueTestDestination, options: %{}}
        )

      :ok = GenServer.cast(worker_pid, {:log_data, :blue, :test_event})

      # sync
      :sys.get_state(worker_pid)
      assert_called(BlueTestDestination.on_success(:ok, :blue, :test_event, %{}))

      :ok = GenServer.cast(worker_pid, {:log_data, :blue, :another_event})

      # sync
      :sys.get_state(worker_pid)
      assert_called(BlueTestDestination.on_success(:good_show, :blue, :another_event, %{}))

      :ok = GenServer.cast(worker_pid, {:log_data, :blue, :error_event})

      # sync
      :sys.get_state(worker_pid)
      assert_called(BlueTestDestination.on_error(:test_reason, :blue, :error_event, %{}))
    end
  end

  test "the destination on_success/4 function is called on success and on_error/4 on error when send_async is true" do
    {:ok, _} = Task.Supervisor.start_link(name: DataLogger.TaskSupervisor)

    with_mock(RedTestDestination,
      on_success: fn
        :ok, :red, :test_event, %{send_async: true} -> :ok
        any, :red, :another_event, %{send_async: true} -> any
      end,
      on_error: fn
        :test_reason, :red, :error_event, %{send_async: true} -> :error
      end,
      initialize: fn options -> options end,
      send_data: fn
        _, :test_event, _ -> :ok
        _, :another_event, _ -> {:ok, :good_show}
        _, :error_event, _ -> {:error, :test_reason}
      end
    ) do
      {:ok, worker_pid} =
        Controller.start_link(
          topic: :red,
          name: :red_test_worker,
          destination: %{module: RedTestDestination, options: %{send_async: true}}
        )

      :ok = GenServer.cast(worker_pid, {:log_data, :red, :test_event})

      :ok = wait_for_task(worker_pid)
      assert_called(RedTestDestination.on_success(:ok, :red, :test_event, %{send_async: true}))

      :ok = GenServer.cast(worker_pid, {:log_data, :red, :another_event})

      :ok = wait_for_task(worker_pid)

      assert_called(
        RedTestDestination.on_success(:good_show, :red, :another_event, %{send_async: true})
      )

      :ok = GenServer.cast(worker_pid, {:log_data, :red, :error_event})

      :ok = wait_for_task(worker_pid)

      assert_called(
        RedTestDestination.on_error(:test_reason, :red, :error_event, %{send_async: true})
      )
    end
  end

  test "the destination controller times out if not used", %{green_worker: pid} do
    Process.sleep(1000 + 100)

    refute Process.alive?(pid)
  end
end
