defmodule Protohackers.JobCentre.Job do
  @enforce_keys [
    :priority,
    :queue,
    :body
  ]

  defstruct @enforce_keys ++ [:id, :deleted?, :client, status: :pending]
end
