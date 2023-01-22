defmodule Protohackers.SpeedDaemon.Message do
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

  defp parse_string(<<str_size, str::binary-size(str_size), rest::binary>>) do
    {:ok, str, rest}
  end

  defp parse_unsigned(bit_size, binary) do
    <<int::unsigned-size(bit_size), rest::binary>> = binary

    {:ok, int, rest}
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
end
