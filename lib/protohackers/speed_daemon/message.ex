defmodule Protohackers.SpeedDaemon.Message do
  defmodule Unknown do
    @enforce_keys []
    defstruct @enforce_keys
  end

  # client -> server

  defmodule Observation do
    @enforce_keys [:plate, :timestamp]
    defstruct @enforce_keys
  end

  defmodule WantHeartBeat do
    @enforce_keys [:interval]
    defstruct @enforce_keys
  end

  defmodule IAmCamera do
    @enforce_keys [:road, :mile, :limit]
    defstruct @enforce_keys
  end

  defmodule IAmDispatcher do
    @enforce_keys [:roads]
    defstruct @enforce_keys
  end

  # server -> client

  defmodule Error do
    @enforce_keys [:msg]
    defstruct @enforce_keys
  end

  defmodule Ticket do
    @enforce_keys [
      :plate,
      :road,
      :from_mile,
      :from_timestamp,
      :to_mile,
      :to_timestamp,
      :speed
    ]

    defstruct @enforce_keys
  end

  defmodule Heartbeat do
    @enforce_keys []
    defstruct @enforce_keys
  end

  def encode(%Error{} = error) do
    <<0x10>> <> encode_str(error.msg)
  end

  def decode_many(binary, acc \\ []) do
    case decode(binary) do
      {:ok, message, rest} ->
        decode_many(rest, [message | acc])

      {:error, _} ->
        {:ok, Enum.reverse(acc), binary}
    end
  end

  def decode(<<0x20, rest::binary>>) do
    with {:ok, plate, rest} <- parse_string(rest),
         {:ok, timestamp, rest} <- parse_unsigned(32, rest) do
      {
        :ok,
        %Observation{
          plate: plate,
          timestamp: timestamp
        },
        rest
      }
    end
  end

  def decode(<<0x40, rest::binary>>) do
    with {:ok, interval, rest} <- parse_unsigned(32, rest) do
      {
        :ok,
        %WantHeartBeat{interval: interval},
        rest
      }
    end
  end

  def decode(<<0x80, rest::binary>>) do
    with {:ok, road, rest} <- parse_unsigned(16, rest),
         {:ok, mile, rest} <- parse_unsigned(16, rest),
         {:ok, limit, rest} <- parse_unsigned(16, rest) do
      {
        :ok,
        %IAmCamera{road: road, mile: mile, limit: limit},
        rest
      }
    end
  end

  def decode(<<0x81, rest::binary>>) do
    with {:ok, num_roads, rest} <- parse_unsigned(8, rest),
         {:ok, roads, rest} <- parse_repeated(num_roads, &parse_unsigned(16, &1), rest) do
      {
        :ok,
        %IAmDispatcher{roads: roads},
        rest
      }
    end
  end

  def decode(<<0x10, rest::binary>>) do
    with {:ok, str, rest} <- parse_string(rest) do
      {:ok, %Error{msg: str}, rest}
    end
  end

  def decode(<<0x21, rest::binary>>) do
    with {:ok, plate, rest} <- parse_string(rest),
         {:ok, road, rest} <- parse_unsigned(16, rest),
         {:ok, from_mile, rest} <- parse_unsigned(16, rest),
         {:ok, from_timestamp, rest} <- parse_unsigned(32, rest),
         {:ok, to_mile, rest} <- parse_unsigned(16, rest),
         {:ok, to_timestamp, rest} <- parse_unsigned(32, rest),
         {:ok, speed, rest} <- parse_unsigned(16, rest) do
      {:ok,
       %Ticket{
         plate: plate,
         road: road,
         from_mile: from_mile,
         from_timestamp: from_timestamp,
         to_mile: to_mile,
         to_timestamp: to_timestamp,
         speed: speed
       }, rest}
    end
  end

  def decode(<<0x41, rest::binary>>) do
    {:ok, %Heartbeat{}, rest}
  end

  def decode(<<type, rest::binary>>)
      when type not in [0x20, 0x40, 0x80, 0x81, 0x10, 0x21, 0x41] do
    {:ok, %Unknown{}, rest}
  end

  def decode(_) do
    {:error, :unmatched}
  end

  defp parse_string(<<str_size, str::binary-size(str_size), rest::binary>>) do
    {:ok, str, rest}
  end

  defp parse_string(_) do
    {:error, :string_unmatched}
  end

  defp parse_unsigned(bit_size, binary) do
    case binary do
      <<int::unsigned-size(bit_size), rest::binary>> ->
        {:ok, int, rest}

      _ ->
        {:error, :unsigned_unmatched}
    end
  end

  defp parse_repeated(times, parser, binary, acc \\ [])

  defp parse_repeated(0, _parser, binary, acc) do
    {:ok, Enum.reverse(acc), binary}
  end

  defp parse_repeated(times, parser, binary, acc) do
    with {:ok, result, rest} <- parser.(binary) do
      parse_repeated(times - 1, parser, rest, [result | acc])
    end
  end

  def encode(%Ticket{} = ticket) do
    <<0x21>> <>
      encode_str(ticket.plate) <>
      encode_unsigned_int(16, ticket.road) <>
      encode_unsigned_int(16, ticket.from_mile) <>
      encode_unsigned_int(32, ticket.from_timestamp) <>
      encode_unsigned_int(16, ticket.to_mile) <>
      encode_unsigned_int(32, ticket.to_timestamp) <>
      encode_unsigned_int(16, ticket.speed)
  end

  def encode(%Heartbeat{}) do
    <<0x41>>
  end

  defp encode_str(string) do
    <<byte_size(string), string::binary>>
  end

  defp encode_unsigned_int(bit_size, int) do
    <<int::size(bit_size)>>
  end
end
