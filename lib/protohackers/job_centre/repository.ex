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

  Kernel.def delete(repo, job_id) do
    get_and_update(repo, [id: job_id, status: {:not, :deleted}], fn job ->
      %{job | status: :deleted}
    end)
  end

  Kernel.def abort(repo, job_id, client) do
    get_and_update(repo, [id: job_id, status: :working, client: client], fn job ->
      job
      |> Map.put(:status, :pending)
      |> Map.put(:client, nil)
    end)
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

          {key, {:not, expected_value}}, jobs ->
            Enum.filter(jobs, &(Map.fetch!(&1, key) != expected_value))

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

defmodule Protohackers.JobCentre.Repository.Agent do
  @enforce_keys [:agent]
  defstruct @enforce_keys

  def new(repo) do
    with {:ok, agent} <- Agent.start_link(fn -> repo end) do
      {:ok, %__MODULE__{agent: agent}}
    end
  end

  defimpl Protohackers.JobCentre.Repository do
    def get_and_update(repo, query, update_fn) do
      case Agent.get_and_update(repo.agent, fn wrapped_repo ->
             case Protohackers.JobCentre.Repository.get_and_update(wrapped_repo, query, update_fn) do
               {:ok, updated_repo, job} ->
                 {{:ok, job}, updated_repo}

               {:error, reason} ->
                 {{:error, reason}, wrapped_repo}
             end
           end) do
        {:ok, job} ->
          {:ok, repo, job}

        {:error, reason} ->
          {:error, reason}
      end
    end

    def insert(repo, record) do
      case Agent.get_and_update(repo.agent, fn wrapped_repo ->
             case Protohackers.JobCentre.Repository.insert(wrapped_repo, record) do
               {:ok, updated_repo, inserted_job} ->
                 {{:ok, inserted_job}, updated_repo}

               {:error, reason} ->
                 {{:error, reason}, wrapped_repo}
             end
           end) do
        {:ok, inserted_job} ->
          {:ok, repo, inserted_job}

        {:error, reason} ->
          {:error, reason}
      end
    end

    def update(repo, record) do
      case Agent.get_and_update(repo.agent, fn wrapped_repo ->
             case Protohackers.JobCentre.Repository.update(wrapped_repo, record) do
               {:ok, updated_repo, updated_job} ->
                 {{:ok, updated_job}, updated_repo}

               {:error, reason} ->
                 {{:error, reason}, wrapped_repo}
             end
           end) do
        {:ok, updated_job} ->
          {:ok, repo, updated_job}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end
end

defmodule Protohackers.JobCentre.Repository.Blocking do
  @enforce_keys [:pid]
  defstruct @enforce_keys

  use GenServer

  def new(repo) do
    with {:ok, pid} <- GenServer.start_link(__MODULE__, repo) do
      {:ok, %__MODULE__{pid: pid}}
    end
  end

  def init(repo) do
    {:ok, repo}
  end

  def handle_call(message, from, wrapped_repo) do
    schedule({message, from}, 0)

    {:noreply, wrapped_repo}
  end

  def handle_info({{:get_and_update, query, update_fn}, from} = message_from_pair, wrapped_repo) do
    case Protohackers.JobCentre.Repository.get_and_update(wrapped_repo, query, update_fn) do
      {:error, _} ->
        schedule(message_from_pair, 1000)
        {:noreply, wrapped_repo}

      {:ok, updated_repo, job} ->
        GenServer.reply(from, {:ok, job})
        {:noreply, updated_repo}
    end
  end

  def handle_info({{:insert, record}, from} = message_from_pair, wrapped_repo) do
    case Protohackers.JobCentre.Repository.insert(wrapped_repo, record) do
      {:error, _} ->
        schedule(message_from_pair, 1000)
        {:noreply, wrapped_repo}

      {:ok, updated_repo, job} ->
        GenServer.reply(from, {:ok, job})
        {:noreply, updated_repo}
    end
  end

  def handle_info({{:update, record}, from} = message_from_pair, wrapped_repo) do
    case Protohackers.JobCentre.Repository.update(wrapped_repo, record) do
      {:error, _} ->
        schedule(message_from_pair, 1000)
        {:noreply, wrapped_repo}

      {:ok, updated_repo, job} ->
        GenServer.reply(from, {:ok, job})
        {:noreply, updated_repo}
    end
  end

  defp schedule(message_from_pair, after_in_ms) do
    Process.send_after(self(), message_from_pair, after_in_ms)
  end

  defimpl Protohackers.JobCentre.Repository do
    def get_and_update(%{pid: pid} = blocking, query, update_fn) do
      {:ok, job} = GenServer.call(pid, {:get_and_update, query, update_fn}, :infinity)

      {:ok, blocking, job}
    end

    def insert(%{pid: pid} = blocking, record) do
      {:ok, job} = GenServer.call(pid, {:insert, record}, :infinity)

      {:ok, blocking, job}
    end

    def update(%{pid: pid} = blocking, record) do
      {:ok, job} = GenServer.call(pid, {:insert, record}, :infinity)

      {:ok, blocking, job}
    end
  end
end
