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
    dispatch_until_empty(state)

    schedule_run()

    {:noreply, state}
  end

  defp schedule_run() do
    Process.send_after(self(), :run, 100)
  end

  defp dispatch_until_empty(state) do
    tickets = Protohackers.SpeedDaemon.Repository.query(state.repo, :tickets)

    Enum.each(tickets, fn ticket ->
      dispatched_tickets =
        Protohackers.SpeedDaemon.Repository.query(state.repo, :dispatched_tickets)

      if !same_car_same_day?(dispatched_tickets, ticket) do
        Registry.dispatch(state.registry, ticket.road, fn entries ->
          if Enum.find(
               entries,
               fn {pid, true} ->
                 match?(:ok, GenServer.call(pid, {:send_ticket, ticket}))
               end
             ) do
            {:ok, _updated_repo} =
              Protohackers.SpeedDaemon.Repository.add(state.repo, :dispatched_ticket, ticket)
          end
        end)
      end
    end)
  end

  defp same_car_same_day?(tickets, ticket) do
    ticket_set = to_day_set(ticket)

    issued_set =
      tickets
      |> Enum.filter(&(&1.plate == ticket.plate))
      |> Enum.map(&to_day_set/1)
      |> Enum.reduce(MapSet.new(), &MapSet.union/2)

    !MapSet.disjoint?(ticket_set, issued_set)
  end

  defp to_day_set(ticket) do
    ticket
    |> to_day_range()
    |> MapSet.new()
  end

  defp to_day_range(ticket) do
    to_day(ticket.from_timestamp)..to_day(ticket.to_timestamp)
  end

  defp to_day(timestamp) do
    floor(timestamp / 86400)
  end
end
