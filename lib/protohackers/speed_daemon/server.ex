defmodule Protohackers.SpeedDaemon.Server do
  use ThousandIsland.Handler

  @impl ThousandIsland.Handler
  def handle_connection(_socket, opts) do
    repo = Keyword.fetch!(opts, :repo)
    registry = Keyword.fetch!(opts, :registry)

    {:continue,
     %{
       want_heartbeat: nil,
       client: nil,
       repo: repo,
       registry: registry,
       buffer: ""
     }}
  end

  @impl ThousandIsland.Handler
  def handle_data(data, socket, state) do
    case Protohackers.SpeedDaemon.Message.decode_many(state.buffer <> data) do
      {:ok, [], binary} ->
        {:continue, %{state | buffer: binary}}

      {:ok, messages, rest} ->
        case Enum.reduce_while(messages, state, fn message, state ->
               case handle_client_message(state, message) do
                 {:noreply, new_state} ->
                   {:cont, new_state}

                 {:error, message} ->
                   {:halt, {:error, message}}
               end
             end) do
          {:error, message} ->
            ThousandIsland.Socket.send(
              socket,
              Protohackers.SpeedDaemon.Message.encode(%Protohackers.SpeedDaemon.Message.Error{
                msg: message
              })
            )

            {:close, state}

          new_state ->
            {:continue, %{new_state | buffer: rest}}
        end
    end
  end

  def handle_client_message(
        %{want_heartbeat: nil} = state,
        %Protohackers.SpeedDaemon.Message.WantHeartBeat{interval: 0} = want_heartbeat
      ) do
    {:noreply, %{state | want_heartbeat: want_heartbeat}}
  end

  def handle_client_message(
        %{want_heartbeat: nil} = state,
        %Protohackers.SpeedDaemon.Message.WantHeartBeat{interval: interval} = want_heartbeat
      )
      when interval > 0 do
    send(self(), :send_heartbeat)

    {:noreply, %{state | want_heartbeat: want_heartbeat}}
  end

  def handle_client_message(
        %{want_heartbeat: want_heartbeat},
        %Protohackers.SpeedDaemon.Message.WantHeartBeat{}
      )
      when not is_nil(want_heartbeat) do
    {:error, "received WantHeartbeat again"}
  end

  def handle_client_message(
        %{client: nil} = state,
        %Protohackers.SpeedDaemon.Message.IAmCamera{} = camera
      ) do
    {:ok, repo} = Protohackers.SpeedDaemon.Repository.add(state.repo, :camera, camera)

    {:noreply, %{state | client: camera, repo: repo}}
  end

  def handle_client_message(
        %{client: client},
        %Protohackers.SpeedDaemon.Message.IAmCamera{}
      )
      when not is_nil(client) do
    {:error, "received IAmCamera again"}
  end

  def handle_client_message(
        %{client: nil} = state,
        %Protohackers.SpeedDaemon.Message.IAmDispatcher{} = dispatcher
      ) do
    for road <- dispatcher.roads do
      {:ok, _owner} = Registry.register(state.registry, road, true)
    end

    {:noreply, %{state | client: dispatcher}}
  end

  def handle_client_message(
        %{client: client},
        %Protohackers.SpeedDaemon.Message.IAmDispatcher{}
      )
      when not is_nil(client) do
    {:error, "received IAmDispatcher again"}
  end

  def handle_client_message(
        %{client: %Protohackers.SpeedDaemon.Message.IAmCamera{}} = state,
        %Protohackers.SpeedDaemon.Message.Observation{} = observation
      ) do
    {:ok, repo} =
      Protohackers.SpeedDaemon.Repository.add(state.repo, :observation, %{
        road: state.client.road,
        camera_mile: state.client.mile,
        plate: observation.plate,
        timestamp: observation.timestamp
      })

    {:noreply, %{state | repo: repo}}
  end

  def handle_client_message(_state, unsupported_message) do
    {:error, "received unexpected message: #{inspect(unsupported_message)}"}
  end

  @impl GenServer
  def handle_info(:send_heartbeat, {socket, state}) do
    ThousandIsland.Socket.send(
      socket,
      Protohackers.SpeedDaemon.Message.encode(%Protohackers.SpeedDaemon.Message.Heartbeat{})
    )

    Process.send_after(self(), :send_heartbeat, state.want_heartbeat.interval * 100)

    {:noreply, {socket, state}}
  end

  @impl GenServer
  def handle_call(
        {:send_ticket, ticket},
        _from,
        {socket, %{client: %Protohackers.SpeedDaemon.Message.IAmDispatcher{}} = state}
      ) do
    ThousandIsland.Socket.send(
      socket,
      Protohackers.SpeedDaemon.Message.Ticket
      |> struct!(ticket)
      |> Protohackers.SpeedDaemon.Message.encode()
    )

    {:reply, :ok, {socket, state}}
  end
end
