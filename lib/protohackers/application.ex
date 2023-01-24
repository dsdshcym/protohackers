defmodule Protohackers.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    {:ok, 5001} = Protohackers.PrimeServer.start_link(5001)
    {:ok, 5003} = Protohackers.BudgetChatServer.start_link(port: 5003, topic: "chatroom")

    children = [
      # Starts a worker by calling: Protohackers.Worker.start_link(arg)
      # {Protohackers.Worker, arg}
      {ThousandIsland, port: 5678, handler_module: Protohackers.EchoServer},
      {Protohackers.MeanServer, port: 5002},
      {Protohackers.UnusualDatabaseServer, port: 5004},
      {Phoenix.PubSub, name: Protohackers.PubSub},
      {Protohackers.BudgetChatServer.Tracker,
       [name: Protohackers.BudgetChatServer.Tracker, pubsub_server: Protohackers.PubSub]},
      Supervisor.child_spec(
        {
          ThousandIsland,
          port: 5005,
          handler_module: Protohackers.MITMServer,
          handler_options: %{
            upstream: %{host: ~c"chat.protohackers.com", port: 16963},
            tony_address: "7YWHMfk9JZe0LM0g1ZauHuiSxhI"
          },
          num_acceptors: 10
        },
        id: :mitm_server
      ),
      {Protohackers.SpeedDaemon.Root, port: 5006}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Protohackers.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
