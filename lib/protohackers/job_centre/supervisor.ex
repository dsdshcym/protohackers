defmodule Protohackers.JobCentre.Supervisor do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts)
  end

  def init(opts) do
    port = Keyword.fetch!(opts, :port)

    {:ok, map_repo} = Protohackers.JobCentre.Repository.Map.new()
    {:ok, shared_repo} = Protohackers.JobCentre.Repository.Agent.new(map_repo)

    children = [
      {ThousandIsland,
       port: port,
       handler_module: Protohackers.JobCentre.Server,
       handler_options: shared_repo,
       transport_options: [packet: :line]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
