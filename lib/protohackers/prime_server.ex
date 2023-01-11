defmodule Protohackers.PrimeServer do
  def start_link(port \\ 0) do
    case :gen_tcp.listen(port, mode: :list, active: false) do
      {:ok, listen_socket} ->
        _pid = spawn_link(fn -> loop(listen_socket) end)
        {:ok, port} = :inet.port(listen_socket)
        {:ok, port}
    end
  end

  defp loop(listen_socket) do
    case :gen_tcp.accept(listen_socket) do
      {:ok, peer_socket} ->
        Task.start_link(fn -> handle_connection(peer_socket) end)
        loop(listen_socket)

      {:error, reason} ->
        {:terminated, reason}
    end
  end

  defp handle_connection(peer_socket, buffer \\ []) do
    case :gen_tcp.recv(peer_socket, 1) do
      {:ok, '\n'} ->
        handle_request(peer_socket, buffer)
        handle_connection(peer_socket, [])

      {:ok, non_terminator} ->
        handle_connection(peer_socket, [buffer, non_terminator])

      {:error, :closed} ->
        :ok
    end
  end

  defp handle_request(peer_socket, request) do
    case Jason.decode(request) do
      {:ok, %{"method" => "isPrime", "number" => number}} when is_number(number) ->
        response = %{
          "method" => "isPrime",
          "prime" => is_prime?(number)
        }

        :gen_tcp.send(peer_socket, [Jason.encode_to_iodata!(response), '\n'])

      {:ok, _malformed_request} ->
        :gen_tcp.send(peer_socket, Jason.encode_to_iodata!(nil))
        :ok = :gen_tcp.close(peer_socket)

      {:error, _decode_error} ->
        :gen_tcp.send(peer_socket, Jason.encode_to_iodata!(nil))
        :ok = :gen_tcp.close(peer_socket)
    end
  end

  defp is_prime?(number) when is_float(number), do: false

  defp is_prime?(number) when is_integer(number) and number < 0, do: false
  defp is_prime?(0), do: false
  defp is_prime?(1), do: false

  defp is_prime?(number) when is_integer(number) do
    Enum.filter(1..number//1, &(rem(number, &1) == 0)) == [1, number]
  end
end
