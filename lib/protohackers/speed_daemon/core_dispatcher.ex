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
    Enum.map(
      Protohackers.SpeedDaemon.Repository.query(state.repo, :tickets),
      fn ticket ->
        Registry.dispatch(state.registry, ticket.road, fn entries ->
          Enum.find(entries, fn {pid, true} ->
            match?(:ok, GenServer.call(pid, {:send_ticket, ticket}))
          end)
        end)
      end
    )

    schedule_run()

    {:noreply, state}
  end

  defp schedule_run() do
    Process.send_after(self(), :run, 100)
  end
end
