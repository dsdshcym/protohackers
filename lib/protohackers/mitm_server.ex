defmodule Protohackers.MITMServer do
  use GenServer

  def start(upstream, tony_address, args \\ []) do
    port = Keyword.get(args, :port, 0)
    pool_size = Keyword.get(args, :pool_size, 1)

    {:ok, listen_socket} = :gen_tcp.listen(port, mode: :binary, packet: :line, active: true)

    for _ <- 1..pool_size do
      {:ok, _pid} =
        DynamicSupervisor.start_child(
          Protohackers.MITMServer.DynamicSupervisor,
          {Protohackers.MITMServer,
           listen_socket: listen_socket, upstream: upstream, tony_address: tony_address}
        )
    end

    {:ok, listen_socket}
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  def init(init_args) do
    upstream = Keyword.fetch!(init_args, :upstream)
    tony_address = Keyword.fetch!(init_args, :tony_address)
    listen_socket = Keyword.fetch!(init_args, :listen_socket)

    {:ok, upstream_socket} =
      :gen_tcp.connect(upstream.host, upstream.port, mode: :binary, packet: :line, active: true)

    {:ok,
     %{
       listen_socket: listen_socket,
       upstream_socket: upstream_socket,
       tony_address: tony_address
     }, {:continue, :accept}}
  end

  def handle_continue(:accept, %{listen_socket: listen_socket} = state) do
    {:ok, client_socket} = :gen_tcp.accept(listen_socket)

    {:noreply, Map.put(state, :client_socket, client_socket)}
  end

  def handle_info({:tcp, client_socket, data}, %{client_socket: client_socket} = state) do
    :ok = :gen_tcp.send(state.upstream_socket, modify_boguscoin_address(data, state.tony_address))

    {:noreply, state}
  end

  def handle_info({:tcp, upstream_socket, data}, %{upstream_socket: upstream_socket} = state) do
    :ok = :gen_tcp.send(state.client_socket, modify_boguscoin_address(data, state.tony_address))

    {:noreply, state}
  end

  def handle_info({:tcp_closed, upstream_socket}, %{upstream_socket: upstream_socket} = state) do
    :ok = :gen_tcp.close(state.client_socket)

    {:noreply, state}
  end

  def handle_info({:tcp_closed, client_socket}, %{client_socket: client_socket} = state) do
    :ok = :gen_tcp.close(state.upstream_socket)

    {:noreply, state}
  end

  def modify_boguscoin_address(data, tony_address) do
    String.replace(data, ~r/(?<=^|\s)7[[:alnum:]]{25,34}(?=\s|$)/, tony_address)
  end
end
