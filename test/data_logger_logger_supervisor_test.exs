defmodule DataLogger.LoggerSupervisorTest do
  use ExUnit.Case

  alias DataLogger.Testing.MemoryDestination
  alias DataLogger.LoggerSupervisor
  alias DataLogger.Logger, as: LoggerWorker

  setup do
    config = [
      destinations: Application.get_env(:data_logger, :destinations)
    ]

    {:ok, supervisor_pid} =
      LoggerSupervisor.start_link(config,
        prefix: :green,
        name: :green_test_supervisor
      )

    %{supervisor: supervisor_pid}
  end

  test "supervises as many worker processes as configured destinations", %{
    supervisor: supervisor_pid
  } do
    assert Supervisor.count_children(supervisor_pid) == %{
             active: 2,
             specs: 2,
             supervisors: 0,
             workers: 2
           }

    [
      {{:green, MemoryDestination, %{destination: _}}, pid1, :worker, [LoggerWorker]},
      {{:green, MemoryDestination, %{destination: _}}, pid2, :worker, [LoggerWorker]}
    ] = Supervisor.which_children(supervisor_pid)

    assert Process.alive?(pid1)
    assert Process.alive?(pid2)
  end
end
