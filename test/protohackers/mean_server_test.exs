defmodule Protohackers.MeanServerTest do
  use ExUnit.Case, async: true

  test "inserts and queries one data" do
    {:ok, peer_socket} = :gen_tcp.connect(~c/localhost/, 5002, mode: :binary, active: false)

    :ok = insert(peer_socket, 12345, 101)
    :ok = insert(peer_socket, 12346, 102)
    :ok = insert(peer_socket, 12347, 100)
    :ok = insert(peer_socket, 40960, 5)

    assert {:ok, <<0, 0, 0, 0x65>>} = query(peer_socket, 12288, 16384)
  end

  defp insert(peer_socket, timestamp, price) do
    :gen_tcp.send(
      peer_socket,
      <<"I", timestamp::signed-big-unit(8)-size(4), price::signed-big-unit(8)-size(4)>>
    )
  end

  defp query(peer_socket, min_timestamp, max_timestamp) do
    :ok =
      :gen_tcp.send(
        peer_socket,
        <<"Q", min_timestamp::signed-big-unit(8)-size(4),
          max_timestamp::signed-big-unit(8)-size(4)>>
      )

    :gen_tcp.recv(peer_socket, 0)
  end
end
