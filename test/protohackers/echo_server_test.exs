defmodule Protohackers.EchoServerTest do
  use ExUnit.Case, async: true

  defp start_server(port, opts \\ []) do
    {:ok, pid} = ThousandIsland.start_link(port: port, handler_module: Protohackers.EchoServer)

    {:ok, %{port: port}} = ThousandIsland.listener_info(pid)

    {:ok, port}
  end

  test "echos tcp binary back" do
    {:ok, port} = start_server(0)

    {:ok, socket} = :gen_tcp.connect('localhost', port, mode: :binary, active: false)
    :gen_tcp.send(socket, "test binary")

    assert {:ok, "test binary"} = :gen_tcp.recv(socket, 0)

    :gen_tcp.shutdown(socket, :read_write)
  end

  test "client shutdown write first" do
    {:ok, port} = start_server(0)

    {:ok, socket} = :gen_tcp.connect('localhost', port, [:binary, active: false])
    :gen_tcp.send(socket, "test binary")

    :gen_tcp.shutdown(socket, :write)

    assert {:ok, "test binary"} = :gen_tcp.recv(socket, 0)

    :gen_tcp.shutdown(socket, :read)
  end

  test "client sends binary several times" do
    {:ok, port} = start_server(0)

    {:ok, socket} = :gen_tcp.connect('localhost', port, [:binary, active: false])
    :gen_tcp.send(socket, "test")
    :gen_tcp.send(socket, " ")
    :gen_tcp.send(socket, "binary")

    :gen_tcp.shutdown(socket, :write)

    assert {:ok, "test binary"} = :gen_tcp.recv(socket, 0)

    :gen_tcp.shutdown(socket, :read)
  end

  test "handles at least 5 simultaneous clients" do
    {:ok, port} = start_server(0, pool_size: 5)

    1..5
    |> Enum.map(fn _index ->
      {:ok, socket} = :gen_tcp.connect('localhost', port, [:binary, active: false])
      socket
    end)
    |> Enum.with_index()
    |> Enum.map(fn {socket, index} ->
      :gen_tcp.send(socket, "test#{index}")

      {socket, "test#{index}"}
    end)
    |> Enum.map(fn {socket, binary_sent} ->
      assert {:ok, ^binary_sent} = :gen_tcp.recv(socket, 0)

      socket
    end)
    |> Enum.each(fn socket ->
      :gen_tcp.shutdown(socket, :read_write)
    end)
  end

  test "timeout so that server can handle next client when pool is used up" do
    {:ok, port} = start_server(0, pool_size: 2)

    1..3
    |> Enum.map(fn _index ->
      {:ok, socket} = :gen_tcp.connect('localhost', port, [:binary, active: false])
      socket
    end)
    |> Enum.with_index()
    |> Enum.map(fn {socket, index} ->
      :gen_tcp.send(socket, "test#{index}")

      {socket, "test#{index}"}
    end)
    |> Enum.map(fn {socket, binary_sent} ->
      assert {:ok, ^binary_sent} = :gen_tcp.recv(socket, 0)

      socket
    end)
    |> Enum.each(fn socket ->
      :gen_tcp.shutdown(socket, :read_write)
    end)
  end
end
