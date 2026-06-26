defmodule DataLogger.Destination.SupervisorTest do
  use ExUnit.Case

  alias DataLogger.Testing.MemoryDestination
  alias DataLogger.Destination.Supervisor, as: DestinationsSupervisor
  alias DataLogger.Destination.Controller

  setup do
    config = [
      destinations: Application.get_env(:data_logger, :destinations)
    ]

    {:ok, supervisor_pid} =
      DestinationsSupervisor.start_link(config,
        topic: :green,
        name: :green_test_supervisor
      )

    %{supervisor: supervisor_pid}
  end

  test "supervises a worker per destination, then auto-shuts-down once they go idle", %{
    supervisor: supervisor_pid
  } do
    # The supervisor is linked to us via start_link; trap exits so its
    # auto-shutdown doesn't take the test process down with it.
    Process.flag(:trap_exit, true)
    ref = Process.monitor(supervisor_pid)

    assert Supervisor.count_children(supervisor_pid) == %{
             active: 2,
             specs: 2,
             supervisors: 0,
             workers: 2
           }

    [
      {{:green, MemoryDestination, %{destination: _}}, pid1, :worker, [Controller]},
      {{:green, MemoryDestination, %{destination: _}}, pid2, :worker, [Controller]}
    ] = Supervisor.which_children(supervisor_pid)

    assert Process.alive?(pid1)
    assert Process.alive?(pid2)

    # Controllers self-stop after their inactivity timeout (~1s). Because they are
    # significant children and the supervisor uses auto_shutdown: :all_significant,
    # the supervisor then tears itself down too — releasing its registry entry so a
    # subsequent DataLogger.log/2 recreates (and re-subscribes) the whole sub-tree.
    assert_receive {:DOWN, ^ref, :process, ^supervisor_pid, _reason}, 3_000

    refute Process.alive?(pid1)
    refute Process.alive?(pid2)
    refute Process.alive?(supervisor_pid)
  end

  test "supervises only the processes with the right topic, if prefix is used" do
    {:ok, supervisor_pid} =
      DestinationsSupervisor.start_link(
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
       [Controller]}
    ] = Supervisor.which_children(supervisor_pid)

    assert Process.alive?(pid)
  end
end
