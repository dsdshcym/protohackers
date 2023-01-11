defmodule Protohackers.PrimeServerTest do
  use ExUnit.Case, async: true

  test "send back a correct response when receiving a conforming request" do
    {:ok, port} = Protohackers.PrimeServer.start_link()

    {:ok, peer_socket} = :gen_tcp.connect(~c/localhost/, port, mode: :list, active: false)

    :ok = :gen_tcp.send(peer_socket, '{"method":"isPrime","number":123}\n')

    assert {:ok, '{"method":"isPrime","prime":false}\n'} = :gen_tcp.recv(peer_socket, 0)
  end

  test "continue receiving request after receiving a conforming request" do
    {:ok, port} = Protohackers.PrimeServer.start_link()

    {:ok, peer_socket} = :gen_tcp.connect(~c/localhost/, port, mode: :list, active: false)

    :ok = :gen_tcp.send(peer_socket, '{"method":"isPrime","number":2}\n')

    assert {:ok, '{"method":"isPrime","prime":true}\n'} = :gen_tcp.recv(peer_socket, 0)

    :ok = :gen_tcp.send(peer_socket, '{"method":"isPrime","number": 2.0}\n')

    assert {:ok, '{"method":"isPrime","prime":false}\n'} = :gen_tcp.recv(peer_socket, 0)
  end

  test "send back a malformed response when receiving a malformed request (not a well-formed JSON object)" do
    {:ok, port} = Protohackers.PrimeServer.start_link()

    {:ok, peer_socket} = :gen_tcp.connect(~c/localhost/, port, mode: :list, active: false)

    :ok = :gen_tcp.send(peer_socket, '[1,2,3]\n')

    assert {:ok, 'null'} = :gen_tcp.recv(peer_socket, 0)
  end

  test "send back a malformed response when receiving a malformed request (number field is missing)" do
    {:ok, port} = Protohackers.PrimeServer.start_link()

    {:ok, peer_socket} = :gen_tcp.connect(~c/localhost/, port, mode: :list, active: false)

    :ok = :gen_tcp.send(peer_socket, '{"method":"isPrime"}\n')

    assert {:ok, 'null'} = :gen_tcp.recv(peer_socket, 0)
  end

  test "send back a malformed response when receiving a malformed request (method field is missing)" do
    {:ok, port} = Protohackers.PrimeServer.start_link()

    {:ok, peer_socket} = :gen_tcp.connect(~c/localhost/, port, mode: :list, active: false)

    :ok = :gen_tcp.send(peer_socket, '{"number": 123}\n')

    assert {:ok, 'null'} = :gen_tcp.recv(peer_socket, 0)
  end

  test "send back a malformed response when receiving a malformed request (the method name is not isPrime)" do
    {:ok, port} = Protohackers.PrimeServer.start_link()

    {:ok, peer_socket} = :gen_tcp.connect(~c/localhost/, port, mode: :list, active: false)

    :ok = :gen_tcp.send(peer_socket, '{"method": "notIsPrime", "number": 123}\n')

    assert {:ok, 'null'} = :gen_tcp.recv(peer_socket, 0)
  end

  test "send back a malformed response when receiving a malformed request (the number value is not a number)" do
    {:ok, port} = Protohackers.PrimeServer.start_link()

    {:ok, peer_socket} = :gen_tcp.connect(~c/localhost/, port, mode: :list, active: false)

    :ok = :gen_tcp.send(peer_socket, '{"method": "isPrime", "number": "123"}\n')

    assert {:ok, 'null'} = :gen_tcp.recv(peer_socket, 0)
  end

  test "disconnect the client when receiving a malformed request" do
    {:ok, port} = Protohackers.PrimeServer.start_link()

    {:ok, peer_socket} = :gen_tcp.connect(~c/localhost/, port, mode: :list, active: false)

    :ok = :gen_tcp.send(peer_socket, 'null\n')

    {:ok, 'null'} = :gen_tcp.recv(peer_socket, 0)
    assert {:error, :closed} = :gen_tcp.recv(peer_socket, 0)
  end

  test "handles request sent in parts" do
    {:ok, port} = Protohackers.PrimeServer.start_link()

    {:ok, peer_socket} = :gen_tcp.connect(~c/localhost/, port, mode: :list, active: false)

    :ok = :gen_tcp.send(peer_socket, '{"method":"isPrime",')
    :ok = :gen_tcp.send(peer_socket, '"number":123}\n')

    assert {:ok, '{"method":"isPrime","prime":false}\n'} = :gen_tcp.recv(peer_socket, 0)
  end

  test "handles at least 5 simultaneous clients" do
    {:ok, port} = Protohackers.PrimeServer.start_link()

    1..5
    |> Enum.map(fn _index ->
      {:ok, peer_socket} = :gen_tcp.connect(~c/localhost/, port, mode: :list, active: false)
      peer_socket
    end)
    |> Enum.map(fn peer_socket ->
      :ok = :gen_tcp.send(peer_socket, '{"method": "isPrime", "number": 123}\n')

      peer_socket
    end)
    |> Enum.map(fn peer_socket ->
      assert {:ok, '{"method":"isPrime","prime":false}\n'} = :gen_tcp.recv(peer_socket, 0)

      peer_socket
    end)
  end
end
