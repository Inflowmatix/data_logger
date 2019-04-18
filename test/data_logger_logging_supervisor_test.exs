defmodule DataLogger.LoggingSupervisorTest do
  use ExUnit.Case

  alias DataLogger.LoggingSupervisor
  alias DataLogger.Testing.MemoryDestination
  alias DataLogger.LoggerSupervisor
  alias DataLogger.Logger, as: LoggerWorker

  setup do
    %{supervisor: Process.whereis(LoggingSupervisor)}
  end

  test "can start a DataLogger.LoggerSupervisor sub-tree for given prefix", %{
    supervisor: supervisor_pid
  } do
    %{
      active: number_of_children,
      specs: number_of_children,
      supervisors: number_of_children,
      workers: 0
    } = Supervisor.count_children(supervisor_pid)

    {:ok, logger_sup_pid} = LoggingSupervisor.start_child(:orange, :test_sup)

    assert %{
             active: number_of_children + 1,
             specs: number_of_children + 1,
             supervisors: number_of_children + 1,
             workers: 0
           } == Supervisor.count_children(supervisor_pid)

    assert Supervisor.which_children(supervisor_pid)
           |> Enum.map(fn {_, pid, :supervisor, [LoggerSupervisor]} -> pid end)
           |> Enum.member?(logger_sup_pid)

    [
      {{:orange, MemoryDestination, [destination: _]}, pid1, :worker, [LoggerWorker]},
      {{:orange, MemoryDestination, [destination: _]}, pid2, :worker, [LoggerWorker]} | _
    ] = Supervisor.which_children(logger_sup_pid)

    assert Process.alive?(pid1)
    assert Process.alive?(pid2)
  end
end
