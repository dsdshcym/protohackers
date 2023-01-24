defprotocol Protohackers.SpeedDaemon.Repository do
  def add(impl, model, map)

  def query(impl, filter, opts \\ [])
end

defmodule Protohackers.SpeedDaemon.Repository.Agent do
  defstruct agent: nil

  def new(repository) do
    {:ok, agent} = Agent.start_link(fn -> repository end)

    %__MODULE__{agent: agent}
  end

  defimpl Protohackers.SpeedDaemon.Repository do
    def add(repo, model, map) do
      :ok =
        Agent.update(repo.agent, fn wrapped_repo ->
          {:ok, wrapped_repo} = Protohackers.SpeedDaemon.Repository.add(wrapped_repo, model, map)
          wrapped_repo
        end)

      {:ok, repo}
    end

    def query(repo, filter, opts) do
      Agent.get(repo.agent, &Protohackers.SpeedDaemon.Repository.query(&1, filter, opts))
    end
  end
end

defmodule Protohackers.SpeedDaemon.Repository.InMemory do
  defstruct cameras: [], observations: [], dispatched_tickets: []

  def new() do
    %__MODULE__{}
  end

  defimpl Protohackers.SpeedDaemon.Repository do
    def add(repo, :camera, camera) do
      {:ok, Map.update!(repo, :cameras, &[camera | &1])}
    end

    def add(repo, :observation, observation) do
      {:ok, Map.update!(repo, :observations, &[observation | &1])}
    end

    def add(repo, :dispatched_ticket, dispatched_ticket) do
      {:ok, Map.update!(repo, :dispatched_tickets, &[dispatched_ticket | &1])}
    end

    def query(repo, :roads, []) do
      repo.cameras
      |> Enum.map(&%{number: &1.road, limit: &1.limit})
      |> Enum.uniq()
    end

    def query(repo, :cameras, queries) do
      Enum.reduce(queries, repo.cameras, fn
        {:road, road}, cameras ->
          Enum.filter(cameras, fn camera -> camera.road == road end)

        {:order_by, {sorter, :mile}}, cameras ->
          Enum.sort_by(cameras, & &1.mile, sorter)
      end)
    end

    def query(repo, :observations, filters) do
      Enum.reduce(filters, repo.observations, fn
        {:road, road_number}, observations ->
          Enum.filter(observations, fn observation -> observation.road == road_number end)

        {:group_by, :plate}, observations ->
          Enum.group_by(observations, & &1.plate)
      end)
    end

    def query(repo, :tickets, []) do
      repo
      |> query(:roads, [])
      |> Enum.flat_map(&query(repo, :tickets_on_road, road: &1))
    end

    def query(repo, :tickets_on_road, filters) do
      road = Keyword.fetch!(filters, :road)

      repo
      |> query(:observations, road: road.number, group_by: :plate)
      |> Enum.flat_map(fn {plate, observations} ->
        for from <- observations,
            to <- observations,
            from.timestamp < to.timestamp,
            speed =
              3600 * abs(to.camera_mile - from.camera_mile) / (to.timestamp - from.timestamp),
            speed >= road.limit,
            do: %{
              plate: plate,
              road: from.road,
              from_mile: from.camera_mile,
              from_timestamp: from.timestamp,
              to_mile: to.camera_mile,
              to_timestamp: to.timestamp,
              speed: round(speed * 100)
            }
      end)
    end
  end
end
