defmodule Protohackers.UnusualDatabaseServer.KVTest do
  use ExUnit.Case, async: true

  test "retrieves a key for which no value exists" do
    assert {:error, :not_found} =
             Protohackers.UnusualDatabaseServer.KV.new()
             |> Protohackers.UnusualDatabaseServer.KV.retrieve("key")
  end

  test "inserts and retrieves kv" do
    assert {:ok, "value"} =
             Protohackers.UnusualDatabaseServer.KV.new()
             |> Protohackers.UnusualDatabaseServer.KV.insert("key", "value")
             |> Protohackers.UnusualDatabaseServer.KV.retrieve("key")
  end

  test "inserts a key twice overwrites the value" do
    assert {:ok, "value2"} =
             Protohackers.UnusualDatabaseServer.KV.new()
             |> Protohackers.UnusualDatabaseServer.KV.insert("key", "value1")
             |> Protohackers.UnusualDatabaseServer.KV.insert("key", "value2")
             |> Protohackers.UnusualDatabaseServer.KV.retrieve("key")
  end

  test "key can be an empty string" do
    assert {:ok, "value"} =
             Protohackers.UnusualDatabaseServer.KV.new()
             |> Protohackers.UnusualDatabaseServer.KV.insert("", "value")
             |> Protohackers.UnusualDatabaseServer.KV.retrieve("")
  end
end

defmodule Protohackers.UnusualDatabaseServerTest do
  use ExUnit.Case, async: true

  @localhost {127, 0, 0, 1}

  test "returns `UnusualDatabaseServer 1.0` when retrieving `version`" do
    {:ok, server} = start_supervised(Protohackers.UnusualDatabaseServer)

    {:ok, port} = Protohackers.UnusualDatabaseServer.fetch_port(server)

    {:ok, socket} = :gen_udp.open(0, mode: :binary, active: false)

    :gen_udp.send(socket, @localhost, port, "version")

    assert {:ok, {@localhost, ^port, "version=UnusualDatabaseServer 1.0"}} =
             :gen_udp.recv(socket, 0, 500)
  end

  test "ignores attempts to modify value under `version`" do
    {:ok, server} = start_supervised(Protohackers.UnusualDatabaseServer)

    {:ok, port} = Protohackers.UnusualDatabaseServer.fetch_port(server)

    {:ok, socket} = :gen_udp.open(0, mode: :binary, active: false)

    :gen_udp.send(socket, @localhost, port, "version=1")
    :gen_udp.send(socket, @localhost, port, "version=12")
    :gen_udp.send(socket, @localhost, port, "version=123")

    :gen_udp.send(socket, @localhost, port, "version")

    assert {:ok, {@localhost, ^port, "version=UnusualDatabaseServer 1.0"}} =
             :gen_udp.recv(socket, 0, 500)
  end

  test "inserts key and retrieve it" do
    {:ok, server} = start_supervised(Protohackers.UnusualDatabaseServer)

    {:ok, port} = Protohackers.UnusualDatabaseServer.fetch_port(server)

    {:ok, socket} = :gen_udp.open(0, mode: :binary, active: false)

    :gen_udp.send(socket, @localhost, port, "key=1")
    :gen_udp.send(socket, @localhost, port, "key")

    assert {:ok, {@localhost, ^port, "key=1"}} = :gen_udp.recv(socket, 0, 500)
  end
end
