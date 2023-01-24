defmodule Protohackers.SpeedDaemon.CoreDispatcher do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(init_arg) do
    repo = Keyword.fetch!(init_arg, :repo)
    registry = Keyword.fetch!(init_arg, :registry)

    schedule_run()

    {:ok, %{repo: repo, registry: registry}}
  end

  def handle_info(:run, state) do
    case Protohackers.SpeedDaemon.Repository.query(state.repo, :undispatched_ticket) do
      nil ->
        :do_nothing

      ticket ->
        Registry.dispatch(state.registry, ticket.road, fn entries ->
          if Enum.find(
               entries,
               fn {pid, true} ->
                 match?(:ok, GenServer.call(pid, {:send_ticket, ticket}))
               end
             ),
             do:
               {:ok, _updated_repo} =
                 Protohackers.SpeedDaemon.Repository.add(state.repo, :dispatched_ticket, ticket)
        end)
    end

    schedule_run()

    {:noreply, state}
  end

  defp schedule_run() do
    Process.send_after(self(), :run, 100)
  end
end
