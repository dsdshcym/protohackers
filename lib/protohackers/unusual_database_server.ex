defmodule Protohackers.UnusualDatabaseServer do
  defmodule KV do
    def new() do
      Map.new()
    end

    def insert(kv, key, value) do
      Map.put(kv, key, value)
    end

    def retrieve(kv, key) do
      case Map.fetch(kv, key) do
        {:ok, value} -> {:ok, value}
        :error -> {:error, :not_found}
      end
    end
  end

  use GenServer

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  def fetch_port(server) do
    GenServer.call(server, :fetch_port)
  end

  def init(init_arg \\ []) do
    port = Keyword.get(init_arg, :port, 0)

    address =
      case System.fetch_env("FLY_APP_NAME") do
        {:ok, _} ->
          # see https://fly.io/docs/app-guides/udp-and-tcp/#the-fly-global-services-address
          {:ok, fly_global_ip} = :inet.getaddr(~c"fly-global-services", :inet)
          fly_global_ip

        :error ->
          {0, 0, 0, 0}
      end

    {:ok, socket} = :gen_udp.open(port, mode: :binary, active: true, ip: address)

    {:ok, %{socket: socket, kv: KV.new()}}
  end

  def handle_call(:fetch_port, _from, state) do
    {:ok, port} = :inet.port(state.socket)

    {:reply, {:ok, port}, state}
  end

  def handle_info({:udp, socket, ip, in_port_no, packet}, %{socket: socket} = state) do
    case parse(packet) do
      {:retrieve, "version"} ->
        :gen_udp.send(socket, ip, in_port_no, "version=UnusualDatabaseServer 1.0")

        {:noreply, state}

      {:insert, "version", _value} ->
        {:noreply, state}

      {:retrieve, key} ->
        case KV.retrieve(state.kv, key) do
          {:ok, value} ->
            :gen_udp.send(socket, ip, in_port_no, "#{key}=#{value}")

          {:error, :not_found} ->
            :gen_udp.send(socket, ip, in_port_no, "#{key}=")
        end

        {:noreply, state}

      {:insert, key, value} ->
        {:noreply, Map.update!(state, :kv, &KV.insert(&1, key, value))}
    end
  end

  defp parse(packet) do
    case String.split(packet, "=", parts: 2) do
      [key] ->
        {:retrieve, key}

      [key, value] ->
        {:insert, key, value}
    end
  end
end
