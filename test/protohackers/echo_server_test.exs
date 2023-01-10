defmodule Protohackers.EchoServerTest do
  use ExUnit.Case, async: true

  test "echos tcp binary back" do
    {:ok, port} = Protohackers.EchoServer.start_link(0)

    {:ok, socket} = :gen_tcp.connect('localhost', port, [:binary, active: false])
    :gen_tcp.send(socket, "test binary")

    assert {:ok, "test binary"} = :gen_tcp.recv(socket, 0)

    :gen_tcp.shutdown(socket, :read_write)
  end

  test "client shutdown write first" do
    {:ok, port} = Protohackers.EchoServer.start_link(0)

    {:ok, socket} = :gen_tcp.connect('localhost', port, [:binary, active: false])
    :gen_tcp.send(socket, "test binary")

    :gen_tcp.shutdown(socket, :write)

    assert {:ok, "test binary"} = :gen_tcp.recv(socket, 0)

    :gen_tcp.shutdown(socket, :read)
  end

  test "client sends binary several times" do
    {:ok, port} = Protohackers.EchoServer.start_link(0)

    {:ok, socket} = :gen_tcp.connect('localhost', port, [:binary, active: false])
    :gen_tcp.send(socket, "test")
    :gen_tcp.send(socket, " ")
    :gen_tcp.send(socket, "binary")

    :gen_tcp.shutdown(socket, :write)

    assert {:ok, "test binary"} = :gen_tcp.recv(socket, 0)

    :gen_tcp.shutdown(socket, :read)
  end
end
