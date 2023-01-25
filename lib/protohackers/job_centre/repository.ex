defprotocol Protohackers.JobCentre.Repository do
  Kernel.def get(repo, query) do
    case get_and_update(repo, query, &Function.identity/1) do
      {:ok, ^repo, job} ->
        {:ok, job}

      {:error, reason} ->
        {:error, reason}
    end
  end

  Kernel.def put(repo, job) do
    insert(repo, job)
  end

  Kernel.def retrieve(repo, client, queues) do
    get_and_update(
      repo,
      [status: :pending, queue: {:in, queues}, order_by: {:desc, :priority}],
      fn job ->
        job
        |> Map.put(:status, :working)
        |> Map.put(:client, client)
      end
    )
  end

  def get_and_update(repo, query, update_fn)

  def insert(repo, record)

  def update(repo, record)
end

defmodule Protohackers.JobCentre.Repository.Map do
  @enforce_keys [:jobs]
  defstruct @enforce_keys

  def new() do
    {:ok, %__MODULE__{jobs: []}}
  end

  defimpl Protohackers.JobCentre.Repository do
    def get_and_update(repo, query, update_fn) do
      jobs =
        Enum.reduce(query, repo.jobs, fn
          {:order_by, {sorter, key}}, jobs ->
            Enum.sort_by(jobs, &Map.fetch!(&1, key), sorter)

          {key, {:in, expected_values}}, jobs ->
            Enum.filter(jobs, &(Map.fetch!(&1, key) in expected_values))

          {key, expected_value}, jobs ->
            Enum.filter(jobs, &(Map.fetch!(&1, key) == expected_value))
        end)

      case jobs do
        [job | _] ->
          update(repo, update_fn.(job))

        [] ->
          {:error, :not_found}
      end
    end

    def insert(repo, job) do
      new_job = Map.put(job, :id, length(repo.jobs) + 1)

      {:ok, %{repo | jobs: [new_job | repo.jobs]}, new_job}
    end

    def update(repo, %{id: id} = updated_job) do
      index = Enum.find_index(repo.jobs, &(&1.id == id))

      {
        :ok,
        %{repo | jobs: List.update_at(repo.jobs, index, fn _ -> updated_job end)},
        updated_job
      }
    end
  end
end
