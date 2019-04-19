defmodule DataLogger.SupervisorTest do
  use ExUnit.Case

  alias DataLogger.Testing.MemoryDestination
  alias DataLogger.Destination.Supervisor, as: DestinationsSupervisor
  alias DataLogger.Destination.Controller

  setup do
    %{supervisor: Process.whereis(DataLogger.Supervisor)}
  end

  test "can start a DataLogger.Destination.Supervisor sub-tree for given prefix", %{
    supervisor: supervisor_pid
  } do
    %{
      active: number_of_children,
      specs: number_of_children,
      supervisors: number_of_children,
      workers: 0
    } = Supervisor.count_children(supervisor_pid)

    {:ok, logger_sup_pid} = DataLogger.Supervisor.start_child(:orange, :test_sup)

    assert %{
             active: number_of_children + 1,
             specs: number_of_children + 1,
             supervisors: number_of_children + 1,
             workers: 0
           } == Supervisor.count_children(supervisor_pid)

    assert Supervisor.which_children(supervisor_pid)
           |> Enum.map(fn {_, pid, :supervisor, [DestinationsSupervisor]} -> pid end)
           |> Enum.member?(logger_sup_pid)

    [
      {{:orange, MemoryDestination, %{destination: _}}, pid1, :worker, [Controller]},
      {{:orange, MemoryDestination, %{destination: _}}, pid2, :worker, [Controller]} | _
    ] = Supervisor.which_children(logger_sup_pid)

    assert Process.alive?(pid1)
    assert Process.alive?(pid2)
  end
end
