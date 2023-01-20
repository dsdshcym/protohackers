defmodule Protohackers.MITMServerTest do
  use ExUnit.Case, async: true

  defmodule MockUpstream do
    use GenServer

    def start_link(args) do
      GenServer.start_link(__MODULE__, args)
    end

    def init(init_args) do
      observer = Keyword.fetch!(init_args, :observer)

      port = Keyword.get(init_args, :port, 0)

      {:ok, listen_socket} = :gen_tcp.listen(port, mode: :binary, packet: :line, active: true)

      {:ok, %{listen_socket: listen_socket, observer: observer}}
    end

    def handle_cast(:start, %{listen_socket: listen_socket} = state) do
      {:ok, peer_socket} = :gen_tcp.accept(listen_socket)

      {:noreply, Map.put(state, :peer_socket, peer_socket)}
    end

    def handle_info({:tcp, peer_socket, data}, %{peer_socket: peer_socket} = state) do
      send(state.observer, {:upstream_received, data})

      {:noreply, state}
    end

    def handle_info({:tcp_closed, peer_socket}, %{peer_socket: peer_socket} = state) do
      send(state.observer, :tcp_to_upstream_closed)

      {:noreply, state}
    end

    def handle_call(:fetch_port, _from, %{listen_socket: listen_socket} = state) do
      {:ok, port} = :inet.port(listen_socket)

      {:reply, port, state}
    end

    def handle_call({:msg_to_client, msg}, _from, %{peer_socket: peer_socket} = state) do
      result = :gen_tcp.send(peer_socket, msg)

      {:reply, result, state}
    end

    def handle_call(:disconnect, _from, %{peer_socket: peer_socket} = state) do
      result = :gen_tcp.close(peer_socket)

      {:reply, result, state}
    end
  end

  defp start_upstream() do
    pid = start_supervised!({MockUpstream, observer: self()})
    port = GenServer.call(pid, :fetch_port)
    :ok = GenServer.cast(pid, :start)

    %{
      host: ~c"localhost",
      port: port,
      pid: pid
    }
  end

  defp start_mitm(upstream, tony_address \\ "just_for_test", pool_size \\ 1) do
    {:ok, socket} = Protohackers.MITMServer.start(upstream, tony_address, pool_size: pool_size)

    {:ok, port} = :inet.port(socket)

    %{
      host: ~c"localhost",
      port: port
    }
  end

  defp start_client(mitm) do
    {:ok, socket} =
      :gen_tcp.connect(mitm.host, mitm.port, mode: :binary, packet: :line, active: false)

    socket
  end

  defp send_tcp_msg(%{pid: pid}, msg) do
    GenServer.call(pid, {:msg_to_client, msg})
  end

  defp send_tcp_msg(socket, msg) when is_port(socket) do
    :gen_tcp.send(socket, msg)
  end

  defp assert_receive_tcp_msg(receiver, msg, opts \\ [])

  defp assert_receive_tcp_msg(socket, msg, _opts) when is_port(socket) do
    assert {:ok, ^msg} = :gen_tcp.recv(socket, 0)
  end

  defp assert_receive_tcp_msg(%{pid: _}, msg, opts) do
    timeout = Keyword.get(opts, :timeout, nil)
    failure_message = Keyword.get(opts, :failure_message, nil)

    assert_receive {:upstream_received, ^msg}, timeout, failure_message
  end

  defp disconnect(%{pid: pid}) do
    GenServer.call(pid, :disconnect)
  end

  defp disconnect(client) when is_port(client) do
    :gen_tcp.close(client)
  end

  defp assert_disconnected(client) when is_port(client) do
    assert {:error, :closed} = :gen_tcp.recv(client, 0)
  end

  defp assert_disconnected(%{pid: _pid}) do
    assert_receive :tcp_to_upstream_closed
  end

  test "forwards messages from client to upstream" do
    upstream = start_upstream()
    mitm = start_mitm(upstream)
    client = start_client(mitm)

    :ok = send_tcp_msg(client, "hello\n")
    assert_receive_tcp_msg(upstream, "hello\n")
  end

  test "forwards messages from upstream to client" do
    upstream = start_upstream()
    mitm = start_mitm(upstream)
    client = start_client(mitm)

    :ok = send_tcp_msg(upstream, "hello\n")
    assert_receive_tcp_msg(client, "hello\n")
  end

  test "modifies Boguscoin addresses from upstream" do
    upstream = start_upstream()
    mitm = start_mitm(upstream, "7YWHMfk9JZe0LM0g1ZauHuiSxhI")
    client = start_client(mitm)

    :ok =
      send_tcp_msg(upstream, "Hi alice, please send payment to 7iKDZEwPZSqIvDnHvVN2r0hUWXD5rHX\n")

    assert_receive_tcp_msg(
      client,
      "Hi alice, please send payment to 7YWHMfk9JZe0LM0g1ZauHuiSxhI\n"
    )
  end

  test "modifies Boguscoin addresses from client" do
    upstream = start_upstream()
    mitm = start_mitm(upstream, "7YWHMfk9JZe0LM0g1ZauHuiSxhI")
    client = start_client(mitm)

    :ok =
      send_tcp_msg(client, "Hi alice, please send payment to 7iKDZEwPZSqIvDnHvVN2r0hUWXD5rHX\n")

    assert_receive_tcp_msg(
      upstream,
      "Hi alice, please send payment to 7YWHMfk9JZe0LM0g1ZauHuiSxhI\n"
    )
  end

  test "disconnects client when upstream disconnects" do
    upstream = start_upstream()
    mitm = start_mitm(upstream)
    client = start_client(mitm)

    :ok = disconnect(upstream)

    assert_disconnected(client)
  end

  test "disconnects upstream when client disconnects" do
    upstream = start_upstream()
    mitm = start_mitm(upstream)
    client = start_client(mitm)

    :ok = disconnect(client)

    assert_disconnected(upstream)
  end

  describe "modify_boguscoin_address/2" do
    test "returns original data no Boguscoin address" do
      assert Protohackers.MITMServer.modify_boguscoin_address("", "test") == ""
      assert Protohackers.MITMServer.modify_boguscoin_address("123456", "test") == "123456"

      assert Protohackers.MITMServer.modify_boguscoin_address(
               "  7F1u3wSD5RbOHQmupo9nx4TnhQ  ",
               "test"
             ) == "  7F1u3wSD5RbOHQmupo9nx4TnhQ  "
    end

    test "replaces Boguscoin address with  tony_address" do
      assert Protohackers.MITMServer.modify_boguscoin_address(
               "7F1u3wSD5RbOHQmupo9nx4TnhQ\n",
               "7Fffffffffffffffffffffffff"
             ) == "7Fffffffffffffffffffffffff\n"

      assert Protohackers.MITMServer.modify_boguscoin_address(
               "7F1u3wSD5RbOHQmupo9nx4TnhQ 123\n",
               "tony"
             ) == "tony 123\n"

      assert Protohackers.MITMServer.modify_boguscoin_address(
               " 7iKDZEwPZSqIvDnHvVN2r0hUWXD5rHX 123\n",
               "tony"
             ) == " tony 123\n"

      assert Protohackers.MITMServer.modify_boguscoin_address(
               "123 7LOrwbDlS8NujgjddyogWgIM93MV5N2VR\n",
               "tony"
             ) == "123 tony\n"

      assert Protohackers.MITMServer.modify_boguscoin_address(
               "7adNeSwJkMakpEcln9HEtthSRtxdmEHOT8T \n",
               "tony"
             ) == "tony \n"

      assert Protohackers.MITMServer.modify_boguscoin_address(
               "7adNeSwJkMakpEcln9HEtthSRtxdmEHOT8T 7adNeSwJkMakpEcln9HEtthSRtxdmEHOT8T \n",
               "tony"
             ) == "tony tony \n"

      assert Protohackers.MITMServer.modify_boguscoin_address(
               "Please pay the ticket price of 15 Boguscoins to one of these addresses: 7UekXCTENCYG4ygXLowo6iDOJPr 7Pk5MBiXSmR7klr2asSyzjHKxhZzNBSzzCb 7YWHMfk9JZe0LM0g1ZauHuiSxhI\n",
               "tony"
             ) ==
               "Please pay the ticket price of 15 Boguscoins to one of these addresses: tony tony tony\n"
    end
  end
end
