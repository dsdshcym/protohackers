defmodule Protohackers.JobCentre.RepositoryTest do
  use ExUnit.Case, async: true

  test "put/2 inserts job that can be get later" do
    {:ok, repo} = Protohackers.JobCentre.Repository.Map.new()

    {:ok, repo, job} =
      Protohackers.JobCentre.Repository.put(repo, %Protohackers.JobCentre.Job{
        queue: "queue1",
        body: %{},
        priority: 123
      })

    assert is_integer(job.id)
    assert {:ok, job} = Protohackers.JobCentre.Repository.get(repo, id: job.id)
  end

  describe "retrieve/3" do
    test "returns pending job" do
      {:ok, repo} = Protohackers.JobCentre.Repository.Map.new()

      {:ok, repo, inserted_job} =
        Protohackers.JobCentre.Repository.insert(repo, %Protohackers.JobCentre.Job{
          status: :pending,
          queue: "test-queue",
          priority: 123,
          body: %{}
        })

      assert {:ok, _repo, received_job} =
               Protohackers.JobCentre.Repository.retrieve(repo, "test-client", ["test-queue"])

      assert received_job.id == inserted_job.id
    end

    test "does not return retrieved (working) jobs" do
      {:ok, repo} = Protohackers.JobCentre.Repository.Map.new()

      {:ok, repo, _inserted_job} =
        Protohackers.JobCentre.Repository.insert(repo, %Protohackers.JobCentre.Job{
          status: :pending,
          queue: "test-queue",
          priority: 123,
          body: %{}
        })

      {:ok, repo, _retrieved_job} =
        Protohackers.JobCentre.Repository.retrieve(repo, "test-client", ["test-queue"])

      assert {:error, :not_found} =
               Protohackers.JobCentre.Repository.retrieve(repo, "test-client", ["test-queue"])
    end

    test "returns the highest priority job" do
      {:ok, repo} = Protohackers.JobCentre.Repository.Map.new()

      {:ok, repo, high_priority_job} =
        Protohackers.JobCentre.Repository.insert(repo, %Protohackers.JobCentre.Job{
          status: :pending,
          queue: "test-queue",
          priority: 100,
          body: %{}
        })

      {:ok, repo, mid_priority_job} =
        Protohackers.JobCentre.Repository.insert(repo, %Protohackers.JobCentre.Job{
          status: :pending,
          queue: "test-queue",
          priority: 50,
          body: %{}
        })

      {:ok, repo, low_priority_job} =
        Protohackers.JobCentre.Repository.insert(repo, %Protohackers.JobCentre.Job{
          status: :pending,
          queue: "test-queue",
          priority: 0,
          body: %{}
        })

      {:ok, repo, retrieved_job} =
        Protohackers.JobCentre.Repository.retrieve(repo, "test-client", ["test-queue"])

      assert retrieved_job.id == high_priority_job.id
      assert retrieved_job.priority == 100
    end

    test "returns the job in the specified queues" do
      {:ok, repo} = Protohackers.JobCentre.Repository.Map.new()

      {:ok, repo, job} =
        Protohackers.JobCentre.Repository.insert(repo, %Protohackers.JobCentre.Job{
          status: :pending,
          queue: "specified-queue",
          priority: 100,
          body: %{}
        })

      {:ok, repo, another_job} =
        Protohackers.JobCentre.Repository.insert(repo, %Protohackers.JobCentre.Job{
          status: :pending,
          queue: "another-specified-queue",
          priority: 100,
          body: %{}
        })

      {:ok, repo, retrieved_job1} =
        Protohackers.JobCentre.Repository.retrieve(repo, "test-client", [
          "specified-queue",
          "another-specified-queue"
        ])

      assert retrieved_job1.id in [job.id, another_job.id]

      {:ok, repo, retrieved_job2} =
        Protohackers.JobCentre.Repository.retrieve(repo, "test-client", [
          "specified-queue",
          "another-specified-queue"
        ])

      assert retrieved_job2.id in ([job.id, another_job.id] -- [retrieved_job1.id])
    end

    test "does not return job in unspecified queues" do
      {:ok, repo} = Protohackers.JobCentre.Repository.Map.new()

      {:ok, repo, job} =
        Protohackers.JobCentre.Repository.insert(repo, %Protohackers.JobCentre.Job{
          status: :pending,
          queue: "un-specified-queue",
          priority: 100,
          body: %{}
        })

      assert {:error, :not_found} =
               Protohackers.JobCentre.Repository.retrieve(repo, "test-client", [
                 "specified-queue",
                 "another-queue"
               ])
    end

    test "updates job's client value to client" do
      {:ok, repo} = Protohackers.JobCentre.Repository.Map.new()

      {:ok, repo, job} =
        Protohackers.JobCentre.Repository.insert(repo, %Protohackers.JobCentre.Job{
          status: :pending,
          queue: "test-queue",
          priority: 100,
          body: %{}
        })

      {:ok, repo, retrieved_job} =
        Protohackers.JobCentre.Repository.retrieve(repo, "test-client", ["test-queue"])

      assert {:ok, %{client: "test-client"}} =
               Protohackers.JobCentre.Repository.get(repo, id: retrieved_job.id)
    end
  end

  describe "delete/2" do
    test "returns {:error, :not_found} when no job" do
      {:ok, repo} = Protohackers.JobCentre.Repository.Map.new()

      assert {:error, :not_found} = Protohackers.JobCentre.Repository.delete(repo, 1)
    end

    test "sets :status to :deleted" do
      {:ok, repo} = Protohackers.JobCentre.Repository.Map.new()

      {:ok, repo, job} =
        Protohackers.JobCentre.Repository.insert(repo, %Protohackers.JobCentre.Job{
          status: :pending,
          queue: "test-queue",
          priority: 100,
          body: %{}
        })

      assert {:ok, repo, %{status: :deleted} = _deleted_job} =
               Protohackers.JobCentre.Repository.delete(repo, job.id)
    end

    test "returns {:error, :not_found} when job was already deleted" do
      {:ok, repo} = Protohackers.JobCentre.Repository.Map.new()

      {:ok, repo, job} =
        Protohackers.JobCentre.Repository.insert(repo, %Protohackers.JobCentre.Job{
          status: :pending,
          queue: "test-queue",
          priority: 100,
          body: %{}
        })

      {:ok, repo, _deleted_job} = Protohackers.JobCentre.Repository.delete(repo, job.id)

      assert {:error, :not_found} = Protohackers.JobCentre.Repository.delete(repo, job.id)
    end

    test "deleted job cannot be retrieved" do
      {:ok, repo} = Protohackers.JobCentre.Repository.Map.new()

      {:ok, repo, job} =
        Protohackers.JobCentre.Repository.insert(repo, %Protohackers.JobCentre.Job{
          status: :pending,
          queue: "test-queue",
          priority: 100,
          body: %{}
        })

      {:ok, repo, _deleted_job} = Protohackers.JobCentre.Repository.delete(repo, job.id)

      assert {:error, :not_found} =
               Protohackers.JobCentre.Repository.retrieve(repo, "test-client", ["test-queue"])
    end
  end

  describe "abort/3" do
    test "returns {:error, :not_found} when no job" do
      {:ok, repo} = Protohackers.JobCentre.Repository.Map.new()

      assert {:error, :not_found} =
               Protohackers.JobCentre.Repository.abort(repo, 1, "test-client")
    end

    test "can only abort retrieved job from the same client" do
      {:ok, repo} = Protohackers.JobCentre.Repository.Map.new()

      {:ok, repo, inserted_job} =
        Protohackers.JobCentre.Repository.insert(repo, %Protohackers.JobCentre.Job{
          status: :pending,
          queue: "test-queue",
          priority: 100,
          body: %{}
        })

      {:ok, repo, retrieved_job} =
        Protohackers.JobCentre.Repository.retrieve(repo, "test-client", ["test-queue"])

      assert {:ok, repo, _aborted_job} =
               Protohackers.JobCentre.Repository.abort(repo, retrieved_job.id, "test-client")
    end

    test "sets job.status back to :pending" do
      {:ok, repo} = Protohackers.JobCentre.Repository.Map.new()

      {:ok, repo, inserted_job} =
        Protohackers.JobCentre.Repository.insert(repo, %Protohackers.JobCentre.Job{
          status: :pending,
          queue: "test-queue",
          priority: 100,
          body: %{}
        })

      {:ok, repo, %{status: :working} = retrieved_job} =
        Protohackers.JobCentre.Repository.retrieve(repo, "test-client", ["test-queue"])

      assert {:ok, repo, %{status: :pending} = _aborted_job} =
               Protohackers.JobCentre.Repository.abort(repo, retrieved_job.id, "test-client")
    end

    test "sets job.client back to nil" do
      {:ok, repo} = Protohackers.JobCentre.Repository.Map.new()

      {:ok, repo, inserted_job} =
        Protohackers.JobCentre.Repository.insert(repo, %Protohackers.JobCentre.Job{
          status: :pending,
          queue: "test-queue",
          priority: 100,
          body: %{}
        })

      {:ok, repo, %{client: "test-client"} = retrieved_job} =
        Protohackers.JobCentre.Repository.retrieve(repo, "test-client", ["test-queue"])

      assert {:ok, repo, %{client: nil} = _aborted_job} =
               Protohackers.JobCentre.Repository.abort(repo, retrieved_job.id, "test-client")
    end

    test "cannot abort un-retrieved job" do
      {:ok, repo} = Protohackers.JobCentre.Repository.Map.new()

      {:ok, repo, inserted_job} =
        Protohackers.JobCentre.Repository.insert(repo, %Protohackers.JobCentre.Job{
          status: :pending,
          queue: "test-queue",
          priority: 100,
          body: %{}
        })

      assert {:error, :not_found} =
               Protohackers.JobCentre.Repository.abort(repo, inserted_job.id, "test-client")
    end

    test "cannot abort retrieved job from another client" do
      {:ok, repo} = Protohackers.JobCentre.Repository.Map.new()

      {:ok, repo, inserted_job} =
        Protohackers.JobCentre.Repository.insert(repo, %Protohackers.JobCentre.Job{
          status: :pending,
          queue: "test-queue",
          priority: 100,
          body: %{}
        })

      {:ok, repo, %{client: "test-client"} = retrieved_job} =
        Protohackers.JobCentre.Repository.retrieve(repo, "test-client", ["test-queue"])

      assert {:error, :not_found} =
               Protohackers.JobCentre.Repository.abort(repo, retrieved_job.id, "another-client")
    end

    test "cannot abort a deleted job" do
      {:ok, repo} = Protohackers.JobCentre.Repository.Map.new()

      {:ok, repo, inserted_job} =
        Protohackers.JobCentre.Repository.insert(repo, %Protohackers.JobCentre.Job{
          status: :pending,
          queue: "test-queue",
          priority: 100,
          body: %{}
        })

      {:ok, repo, %{client: "test-client"} = retrieved_job} =
        Protohackers.JobCentre.Repository.retrieve(repo, "test-client", ["test-queue"])

      {:ok, repo, deleted_job} = Protohackers.JobCentre.Repository.delete(repo, retrieved_job.id)

      assert {:error, :not_found} =
               Protohackers.JobCentre.Repository.abort(repo, deleted_job.id, "test-client")
    end

    test "aborted job can be retrieved again (even by another client)" do
      {:ok, repo} = Protohackers.JobCentre.Repository.Map.new()

      {:ok, repo, inserted_job} =
        Protohackers.JobCentre.Repository.insert(repo, %Protohackers.JobCentre.Job{
          status: :pending,
          queue: "test-queue",
          priority: 100,
          body: %{}
        })

      {:ok, repo, %{client: "test-client"} = retrieved_job} =
        Protohackers.JobCentre.Repository.retrieve(repo, "test-client", ["test-queue"])

      assert {:ok, repo, aborted_job} =
               Protohackers.JobCentre.Repository.abort(repo, retrieved_job.id, "test-client")

      assert {:ok, repo, _retrieved_job} =
               Protohackers.JobCentre.Repository.retrieve(repo, "another-client", ["test-queue"])
    end
  end
end
