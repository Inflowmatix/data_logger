defmodule DataLoggerTest do
  use ExUnit.Case

  alias DataLogger.Testing.MemoryDestination

  setup do
    {:ok, pid} = start_supervised(MemoryDestination)

    %{memory_destination: pid}
  end

  describe "DataLogger.log/2" do
    test "sends the passed data to all the destinations configured", %{
      memory_destination: memory_destination
    } do
      :ok = DataLogger.log("test_prefix", {memory_destination, :test_event})

      data =
        memory_destination
        |> MemoryDestination.get_data_per_topic(2)

      assert Map.keys(data) == ["test_prefix"]
      assert Map.get(data, "test_prefix") |> Enum.member?({:test_event, %{destination: 1}})
      assert Map.get(data, "test_prefix") |> Enum.member?({:test_event, %{destination: 2}})
    end

    test "sends the passed data to all the destinations configured for multiple prefixes",
         %{
           memory_destination: memory_destination
         } do
      :ok = DataLogger.log("test_prefix1", {memory_destination, :test_event1})
      :ok = DataLogger.log("test_prefix2", {memory_destination, :test_event2})

      data =
        memory_destination
        |> MemoryDestination.get_data_per_topic(4)

      assert Map.keys(data) |> Enum.count() == 2
      assert Map.keys(data) |> Enum.member?("test_prefix1")
      assert Map.keys(data) |> Enum.member?("test_prefix2")

      assert Map.get(data, "test_prefix1") |> Enum.member?({:test_event1, %{destination: 1}})
      assert Map.get(data, "test_prefix1") |> Enum.member?({:test_event1, %{destination: 2}})

      assert Map.get(data, "test_prefix2") |> Enum.member?({:test_event2, %{destination: 1}})
      assert Map.get(data, "test_prefix2") |> Enum.member?({:test_event2, %{destination: 2}})
    end

    test "sending with :send_async set to true works as expected", %{
      memory_destination: memory_destination
    } do
      MemoryDestination.with_async_destination(fn ->
        :ok = DataLogger.log("test_prefix", {memory_destination, :test_event})

        data =
          memory_destination
          |> MemoryDestination.get_data_per_topic(3)

        assert Map.keys(data) == ["test_prefix"]
        assert Map.get(data, "test_prefix") |> Enum.member?({:test_event, %{destination: 1}})
        assert Map.get(data, "test_prefix") |> Enum.member?({:test_event, %{destination: 2}})

        assert Map.get(data, "test_prefix")
               |> Enum.member?({:test_event, %{destination: 3, send_async: true}})
      end)
    end
  end
end
