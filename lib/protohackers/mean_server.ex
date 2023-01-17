defmodule Protohackers.MeanServer do
  use GenServer

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  def init(init_arg) do
    port = Keyword.fetch!(init_arg, :port)

    {:ok, listen_socket} = :gen_tcp.listen(port, mode: :list, active: false)

    {:ok, listen_socket, {:continue, :listen}}
  end

  def handle_continue(:listen, listen_socket) do
    case :gen_tcp.accept(listen_socket) do
      {:ok, peer_socket} ->
        Task.start(fn -> handle_connection(peer_socket) end)
        {:noreply, listen_socket, {:continue, :listen}}

      {:error, reason} ->
        {:terminated, reason}
    end
  end

  defp handle_connection(peer_socket) do
    Stream.resource(
      fn -> peer_socket end,
      fn peer_socket ->
        case :gen_tcp.recv(peer_socket, 0) do
          {:ok, list} -> {list, peer_socket}
          {:error, :closed} -> {:halt, peer_socket}
        end
      end,
      fn _closed_socket -> :ok end
    )
    |> Stream.chunk_every(9)
    |> Stream.map(&IO.iodata_to_binary/1)
    |> Enum.reduce(%{}, fn
      <<"I", timestamp::signed-big-unit(8)-size(4), price::signed-big-unit(8)-size(4)>>, state ->
        Map.put(state, timestamp, price)

      <<"Q", min_timestamp::signed-big-unit(8)-size(4),
        max_timestamp::signed-big-unit(8)-size(4)>>,
      state ->
        mean =
          state
          |> Enum.filter(fn {timestamp, _price} ->
            timestamp >= min_timestamp and timestamp <= max_timestamp
          end)
          |> Enum.map(fn {_timestamp, price} -> price end)
          |> then(fn
            [] -> 0
            list -> div(Enum.sum(list), length(list))
          end)

        :gen_tcp.send(peer_socket, to_response(mean))

        state
    end)
    |> Stream.run()
  end

  defp to_response(mean) do
    <<mean::signed-big-unit(8)-size(4)>>
  end

  def terminate(_, listen_socket) do
    :gen_tcp.close(listen_socket)
  end
end
