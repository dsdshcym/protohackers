defmodule Protohackers.SpeedDaemon.Server do
  use ThousandIsland.Handler

  @impl ThousandIsland.Handler
  def handle_connection(_socket, []) do
    {:continue,
     %{
       want_heartbeat: nil,
       buffer: ""
     }}
  end

  @impl ThousandIsland.Handler
  def handle_data(data, socket, state) do
    case Protohackers.SpeedDaemon.Message.decode(state.buffer <> data) do
      {:ok, message, rest} ->
        case handle_client_message(state, message) do
          {:noreply, new_state} ->
            {:continue, %{new_state | buffer: rest}}

          {:error, message} ->
            ThousandIsland.Socket.send(
              socket,
              Protohackers.SpeedDaemon.Message.encode(%Protohackers.SpeedDaemon.Message.Error{
                msg: message
              })
            )

            {:close, state}
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

  @impl GenServer
  def handle_info(:send_heartbeat, {socket, state}) do
    ThousandIsland.Socket.send(
      socket,
      Protohackers.SpeedDaemon.Message.encode(%Protohackers.SpeedDaemon.Message.Heartbeat{})
    )

    Process.send_after(self(), :send_heartbeat, state.want_heartbeat.interval * 100)

    {:noreply, {socket, state}}
  end
end
