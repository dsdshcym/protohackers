defmodule Protohackers.SpeedDaemon.Root do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts)
  end

  def init(opts) do
    port = Keyword.fetch!(opts, :port)

    repo =
      Protohackers.SpeedDaemon.Repository.Agent.new(
        Protohackers.SpeedDaemon.Repository.InMemory.new()
      )

    registry = :speed_daemon_registry

    children = [
      {Registry, keys: :duplicate, name: registry},
      {Protohackers.SpeedDaemon.CoreDispatcher, repo: repo, registry: registry},
      {
        ThousandIsland,
        port: port,
        handler_module: Protohackers.SpeedDaemon.Server,
        handler_options: [repo: repo, registry: registry]
      }
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
