defmodule Protohackers.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    {:ok, 5678} = Protohackers.EchoServer.start_link(5678)
    {:ok, 5001} = Protohackers.PrimeServer.start_link(5001)
    {:ok, 5003} = Protohackers.BudgetChatServer.start_link(port: 5003, topic: "chatroom")

    children = [
      # Starts a worker by calling: Protohackers.Worker.start_link(arg)
      # {Protohackers.Worker, arg}
      {Protohackers.MeanServer, port: 5002},
      {Protohackers.UnusualDatabaseServer, port: 5004},
      {Phoenix.PubSub, name: Protohackers.PubSub},
      {Protohackers.BudgetChatServer.Tracker,
       [name: Protohackers.BudgetChatServer.Tracker, pubsub_server: Protohackers.PubSub]},
      {DynamicSupervisor, name: Protohackers.MITMServer.DynamicSupervisor}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Protohackers.Supervisor]
    result = Supervisor.start_link(children, opts)

    {:ok, _} =
      Protohackers.MITMServer.start(
        %{host: ~c"chat.protohackers.com", port: 16963},
        "7YWHMfk9JZe0LM0g1ZauHuiSxhI",
        port: 5005,
        pool_size: 100
      )

    result
  end
end
