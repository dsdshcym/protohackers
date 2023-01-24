defmodule Protohackers.SpeedDaemon.ServerTest do
  use ExUnit.Case, async: true

  defp start_server!(opts \\ []) do
    repo =
      Keyword.get_lazy(opts, :repo, fn ->
        Protohackers.SpeedDaemon.Repository.Agent.new(
          Protohackers.SpeedDaemon.Repository.InMemory.new()
        )
      end)

    registry =
      Keyword.get_lazy(opts, :registry, fn ->
        start_supervised!({Registry, keys: :unique, name: :speed_daemon_registry_for_test})

        :speed_daemon_registry_for_test
      end)

    {:ok, pid} =
      start_supervised({
        ThousandIsland,
        port: 0,
        handler_module: Protohackers.SpeedDaemon.Server,
        handler_options: [repo: repo, registry: registry]
      })

    {:ok, %{port: port}} = ThousandIsland.listener_info(pid)

    %{
      host: ~c"localhost",
      port: port
    }
  end

  defp start_client!(server) do
    {:ok, socket} = :gen_tcp.connect(server.host, server.port, mode: :binary, active: true)

    socket
  end

  defp send_tcp_message(socket, msg) do
    :gen_tcp.send(socket, msg)
  end

  defp assert_tcp_receive(socket, msg, timeout \\ nil) do
    assert_receive {:tcp, ^socket, ^msg}, timeout
  end

  defp refute_tcp_receive(socket, msg, timeout) do
    refute_receive {:tcp, ^socket, ^msg}, timeout
  end

  describe "heartbeat" do
    test "refuses heartbeat" do
      server = start_server!()

      client = start_client!(server)

      :ok = send_tcp_message(client, <<0x40, 0x00, 0x00, 0x00, 0x00>>)

      refute_tcp_receive(
        client,
        Protohackers.SpeedDaemon.Message.encode(%Protohackers.SpeedDaemon.Message.Heartbeat{}),
        1000
      )
    end

    test "receives heartbeat at interval 1" do
      server = start_server!()

      client = start_client!(server)

      :ok = send_tcp_message(client, <<0x40, 0x00, 0x00, 0x00, 0x01>>)

      assert_tcp_receive(
        client,
        Protohackers.SpeedDaemon.Message.encode(%Protohackers.SpeedDaemon.Message.Heartbeat{}),
        50
      )

      assert_tcp_receive(
        client,
        Protohackers.SpeedDaemon.Message.encode(%Protohackers.SpeedDaemon.Message.Heartbeat{}),
        150
      )
    end

    test "errors when client sends multiple WantHeartBeat message" do
      server = start_server!()

      client = start_client!(server)

      :ok = send_tcp_message(client, <<0x40, 0x00, 0x00, 0x00, 0x01>>)

      assert_tcp_receive(
        client,
        Protohackers.SpeedDaemon.Message.encode(%Protohackers.SpeedDaemon.Message.Heartbeat{}),
        50
      )

      :ok = send_tcp_message(client, <<0x40, 0x00, 0x00, 0x00, 0x01>>)

      assert_tcp_receive(
        client,
        Protohackers.SpeedDaemon.Message.encode(%Protohackers.SpeedDaemon.Message.Error{
          msg: "received WantHeartbeat again"
        }),
        100
      )
    end
  end
end
