defmodule Protohackers.BudgetChatServer do
  defmodule Tracker do
    use Phoenix.Tracker

    def start_link(opts) do
      opts = Keyword.merge([name: __MODULE__], opts)
      Phoenix.Tracker.start_link(__MODULE__, opts, opts)
    end

    def init(opts) do
      server = Keyword.fetch!(opts, :pubsub_server)
      {:ok, %{pubsub_server: server, node_name: Phoenix.PubSub.node_name(server)}}
    end

    def handle_diff(diff, state) do
      for {topic, {joins, leaves}} <- diff do
        for {key, meta} <- joins do
          msg = {:join, key, meta}
          Phoenix.PubSub.direct_broadcast!(state.node_name, state.pubsub_server, topic, msg)
        end

        for {key, meta} <- leaves do
          msg = {:leave, key, meta}
          Phoenix.PubSub.direct_broadcast!(state.node_name, state.pubsub_server, topic, msg)
        end
      end

      {:ok, state}
    end
  end

  defmodule UserServer do
    use GenServer

    def start_link(args) do
      GenServer.start_link(__MODULE__, args)
    end

    def init(init_arg) do
      listen_socket = Keyword.fetch!(init_arg, :listen_socket)
      topic = Keyword.fetch!(init_arg, :topic)

      {:ok, %{listen_socket: listen_socket, topic: topic}, {:continue, :wait_for_connection}}
    end

    def handle_continue(:wait_for_connection, state) do
      case :gen_tcp.accept(state.listen_socket) do
        {:ok, peer_socket} ->
          {:noreply, Map.put(state, :peer_socket, peer_socket), {:continue, :prompt_for_name}}

        {:error, reason} ->
          {:stop, reason}
      end
    end

    def handle_continue(:prompt_for_name, state) do
      :gen_tcp.send(state.peer_socket, "Welcome to budgetchat! What shall I call you?\n")

      case :gen_tcp.recv(state.peer_socket, 0) do
        {:ok, username} ->
          username = String.trim(username)

          with {:ok, username} <- validate_username(username),
               {:ok, _ref} <-
                 Phoenix.Tracker.track(
                   Tracker,
                   Process.whereis(Tracker),
                   state.topic,
                   username,
                   %{
                     username: username
                   }
                 ) do
            existing_users_prompt =
              Tracker
              |> Phoenix.Tracker.list(state.topic)
              |> Enum.reject(fn {username_in_room, _metadata} ->
                username_in_room == username
              end)
              |> Enum.map(fn {username_in_room, _metadata} -> username_in_room end)
              |> Enum.join(", ")

            :ok = :inet.setopts(state.peer_socket, active: true)

            :gen_tcp.send(state.peer_socket, "* The room contains: #{existing_users_prompt}\n")

            Phoenix.PubSub.subscribe(Protohackers.PubSub, state.topic)

            {:noreply, Map.put(state, :username, username)}
          else
            {:error, _} ->
              :gen_tcp.close(state.peer_socket)

              {:noreply, Map.take(state, [:listen_socket, :topic]),
               {:continue, :wait_for_connection}}
          end
      end
    end

    defp validate_username(username) do
      if String.length(username) >= 1 &&
           username
           |> String.to_charlist()
           |> Enum.all?(&(&1 in ?a..?z or &1 in ?A..?Z or &1 in ?0..?9)) do
        {:ok, username}
      else
        {:error, :invalid_username}
      end
    end

    def handle_info({:tcp, socket, message}, %{peer_socket: socket} = state) do
      message = String.trim(message)

      :ok =
        Phoenix.PubSub.broadcast(
          Protohackers.PubSub,
          state.topic,
          {:chat_message, state.username, message}
        )

      {:noreply, state}
    end

    def handle_info({:tcp_closed, socket}, %{peer_socket: socket} = state) do
      Phoenix.Tracker.untrack(Tracker, Process.whereis(Tracker), state.topic, state.username)

      {:noreply, Map.take(state, [:listen_socket, :topic]), {:continue, :wait_for_connection}}
    end

    def handle_info({:join, username, _metadata}, state) do
      :gen_tcp.send(state.peer_socket, "* #{username} has entered the room\n")

      {:noreply, state}
    end

    def handle_info({:leave, username, _metadata}, state) do
      :gen_tcp.send(state.peer_socket, "* #{username} has left the room\n")

      {:noreply, state}
    end

    def handle_info({:chat_message, from, _message}, %{username: from} = state) do
      {:noreply, state}
    end

    def handle_info({:chat_message, from, message}, state) do
      :gen_tcp.send(state.peer_socket, "[#{from}] #{message}\n")

      {:noreply, state}
    end
  end

  def start_link(opts \\ []) do
    topic = Keyword.get_lazy(opts, :topic, fn -> :rand.bytes(10) end)
    port = Keyword.get(opts, :port, 0)

    case :gen_tcp.listen(port, mode: :binary, packet: :line, active: false) do
      {:ok, listen_socket} ->
        for _ <- 1..10 do
          UserServer.start_link(listen_socket: listen_socket, topic: topic)
        end

        {:ok, port} = :inet.port(listen_socket)
        {:ok, port}
    end
  end
end
