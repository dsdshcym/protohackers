defmodule Protohackers.EchoServer do
  def start_link(port) do
    case :gen_tcp.listen(port, [:binary, active: false]) do
      {:ok, listen_socket} ->
        spawn_link(__MODULE__, :server, [listen_socket])
        {:ok, listen_port} = :inet.port(listen_socket)
        {:ok, listen_port}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def server(listen_socket) do
    case :gen_tcp.accept(listen_socket) do
      {:ok, socket} ->
        loop(socket)
        server(listen_socket)

      {:error, reason} ->
        {:terminated, reason}
    end
  end

  defp loop(socket) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, binary} ->
        :gen_tcp.send(socket, binary)

        loop(socket)

      {:error, :closed} ->
        {:ok, :socket_closed}
    end
  end
end
