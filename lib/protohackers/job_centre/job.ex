defmodule Protohackers.JobCentre.Job do
  @enforce_keys [
    :priority,
    :queue,
    :body
  ]

  defstruct @enforce_keys ++ [:id, :client, status: :pending]
end
