defmodule Protohackers.JobCentre.Server do
  use ThousandIsland.Handler

  @impl ThousandIsland.Handler
  def handle_connection(_socket, repo) do
    {:continue, %{repo: repo, this_client: make_ref()}}
  end

  @impl ThousandIsland.Handler
  def handle_data(data, socket, state) do
    case Jason.decode(data) do
      {:error, reason} ->
        send_reply(socket, :error, error: "invalid json: #{inspect(reason)}")

        {:continue, state}

      {:ok, parsed_json} ->
        handle_request(socket, state, parsed_json)
    end
  end

  @impl ThousandIsland.Handler
  def handle_close(_socket, state) do
    Protohackers.JobCentre.Repository.abort_all(state.repo, state.this_client)

    :ok
  end

  defp handle_request(socket, state, %{
         "request" => "put",
         "queue" => queue,
         "job" => job_body,
         "pri" => priority
       })
       when is_binary(queue) and is_integer(priority) and priority >= 0 do
    {:ok, updated_repo, inserted_job} =
      Protohackers.JobCentre.Repository.insert(state.repo, %Protohackers.JobCentre.Job{
        queue: queue,
        body: job_body,
        priority: priority
      })

    send_reply(socket, :ok, id: inserted_job.id)

    {:continue, %{state | repo: updated_repo}}
  end

  defp handle_request(socket, state, %{"request" => "get", "queues" => queues} = get_request)
       when is_list(queues) do
    maybe_blocking_repo =
      case Map.get(get_request, "wait", false) do
        false ->
          state.repo

        true ->
          {:ok, blocking_repo} = Protohackers.JobCentre.Repository.Blocking.new(state.repo)
          blocking_repo
      end

    case Protohackers.JobCentre.Repository.retrieve(
           maybe_blocking_repo,
           state.this_client,
           queues
         ) do
      {:ok, updated_repo, retrieved_job} ->
        send_reply(socket, :ok,
          id: retrieved_job.id,
          job: retrieved_job.body,
          pri: retrieved_job.priority,
          queue: retrieved_job.queue
        )

        {:continue, %{state | repo: updated_repo}}

      {:error, :not_found} ->
        send_reply(socket, :"no-job")

        {:continue, state}
    end
  end

  defp handle_request(socket, state, %{"request" => "abort", "id" => job_id})
       when is_integer(job_id) do
    case Protohackers.JobCentre.Repository.abort(state.repo, job_id, state.this_client) do
      {:ok, updated_repo, _aborted_job} ->
        send_reply(socket, :ok)

        {:continue, %{state | repo: updated_repo}}

      {:error, :not_found} ->
        send_reply(socket, :"no-job")

        {:continue, state}
    end
  end

  defp handle_request(socket, state, %{"request" => "delete", "id" => job_id})
       when is_integer(job_id) do
    case Protohackers.JobCentre.Repository.delete(state.repo, job_id) do
      {:ok, updated_repo, _deleted_job} ->
        send_reply(socket, :ok)

        {:continue, %{state | repo: updated_repo}}

      {:error, :not_found} ->
        send_reply(socket, :"no-job")

        {:continue, state}
    end
  end

  defp handle_request(socket, state, invalid_request) do
    send_reply(socket, :error, error: "invalid request: #{inspect(invalid_request)}")

    {:continue, state}
  end

  defp send_reply(socket, status, payload \\ []) do
    message =
      payload
      |> Keyword.put(:status, status)
      |> Map.new()
      |> Jason.encode!()

    ThousandIsland.Socket.send(
      socket,
      [message, "\n"]
    )
  end

  @impl GenServer
  def handle_info({:EXIT, _blocker, :normal}, {socket, state}) do
    {:noreply, {socket, state}}
  end
end
