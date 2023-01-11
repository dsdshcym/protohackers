defmodule Protohackers.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    {:ok, 5678} = Protohackers.EchoServer.start_link(5678)
    {:ok, 5001} = Protohackers.PrimeServer.start_link(5001)

    children = [
      # Starts a worker by calling: Protohackers.Worker.start_link(arg)
      # {Protohackers.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Protohackers.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
