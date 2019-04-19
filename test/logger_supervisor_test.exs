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
        topic: :green,
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

  test "supervises only the processes with the right topic, if prefix is used" do
    {:ok, supervisor_pid} =
      LoggerSupervisor.start_link(
        [
          destinations: [
            {MemoryDestination, %{destination: 1}},
            {MemoryDestination, %{destination: 2, prefix: :purple}}
          ]
        ],
        topic: :purple_car,
        name: :purple_test_supervisor
      )

    assert Supervisor.count_children(supervisor_pid) == %{
             active: 1,
             specs: 1,
             supervisors: 0,
             workers: 1
           }

    [
      {{:purple_car, MemoryDestination, %{destination: _, prefix: :purple}}, pid, :worker,
       [LoggerWorker]}
    ] = Supervisor.which_children(supervisor_pid)

    assert Process.alive?(pid)
  end
end
