defmodule Protohackers.JobCentre.ServerTest do
  use ExUnit.Case, async: true

  test "example" do
    {:ok, map_repo} = Protohackers.JobCentre.Repository.Map.new()
    {:ok, shared_repo} = Protohackers.JobCentre.Repository.Agent.new(map_repo)
    Process.unlink(shared_repo.agent)

    {:ok, server} =
      start_supervised(
        {ThousandIsland,
         port: 0,
         handler_module: Protohackers.JobCentre.Server,
         handler_options: shared_repo,
         transport_options: [packet: :line]}
      )

    {:ok, %{port: port}} = ThousandIsland.listener_info(server)

    {:ok, client} = :gen_tcp.connect(~c"localhost", port, mode: :binary, packet: :line)

    :ok =
      :gen_tcp.send(
        client,
        ~s/{"request":"put","queue":"queue1","job":{"title":"example-job"},"pri":123}\n/
      )

    assert_receive {:tcp, ^client, ~s/{"id":1,"status":"ok"}\n/}

    :ok =
      :gen_tcp.send(
        client,
        ~s/{"request":"get","queues":["queue1"]}\n/
      )

    assert_receive {:tcp, ^client,
                    ~s/{"id":1,"job":{"title":"example-job"},"pri":123,"queue":"queue1","status":"ok"}\n/}

    :ok =
      :gen_tcp.send(
        client,
        ~s/{"request":"abort","id":1}\n/
      )

    assert_receive {:tcp, ^client, ~s/{"status":"ok"}\n/}

    :ok =
      :gen_tcp.send(
        client,
        ~s/{"request":"get","queues":["queue1"]}\n/
      )

    assert_receive {:tcp, ^client,
                    ~s/{"id":1,"job":{"title":"example-job"},"pri":123,"queue":"queue1","status":"ok"}\n/}

    :ok =
      :gen_tcp.send(
        client,
        ~s/{"request":"delete","id":1}\n/
      )

    assert_receive {:tcp, ^client, ~s/{"status":"ok"}\n/}

    :ok =
      :gen_tcp.send(
        client,
        ~s/{"request":"get","queues":["queue1"]}\n/
      )

    assert_receive {:tcp, ^client, ~s/{"status":"no-job"}\n/}

    :ok =
      :gen_tcp.send(
        client,
        ~s/{"request":"get","queues":["queue1"],"wait":true}\n/
      )

    refute_receive {:tcp, ^client, _}

    {:ok, another_client} = :gen_tcp.connect(~c"localhost", port, mode: :binary, packet: :line)

    :ok =
      :gen_tcp.send(
        another_client,
        ~s/{"request":"put","queue":"queue1","job":{"title":"new-example-job"},"pri":123}\n/
      )

    assert_receive(
      {
        :tcp,
        ^client,
        ~s/{"id":2,"job":{"title":"new-example-job"},"pri":123,"queue":"queue1","status":"ok"}\n/
      },
      500
    )
  end

  test "abort jobs when disconnecting" do
    {:ok, map_repo} = Protohackers.JobCentre.Repository.Map.new()

    {:ok, shared_repo} = Protohackers.JobCentre.Repository.Agent.new(map_repo)
    Process.unlink(shared_repo.agent)

    {:ok, server} =
      start_supervised(
        {ThousandIsland,
         port: 0,
         handler_module: Protohackers.JobCentre.Server,
         handler_options: shared_repo,
         transport_options: [packet: :line]}
      )

    {:ok, %{port: port}} = ThousandIsland.listener_info(server)

    {:ok, client} = :gen_tcp.connect(~c"localhost", port, mode: :binary, packet: :line)

    :ok =
      :gen_tcp.send(
        client,
        ~s/{"request":"put","queue":"queue1","job":{"title":"example-job"},"pri":123}\n/
      )

    :ok =
      :gen_tcp.send(
        client,
        ~s/{"request":"get","queues":["queue1"]}\n/
      )

    assert_receive {
      :tcp,
      ^client,
      ~s/{"id":1,"job":{"title":"example-job"},"pri":123,"queue":"queue1","status":"ok"}\n/
    }

    :ok = :gen_tcp.close(client)

    {:ok, another_client} = :gen_tcp.connect(~c"localhost", port, mode: :binary, packet: :line)

    :ok =
      :gen_tcp.send(
        another_client,
        ~s/{"request":"get","queues":["queue1"],"wait":true}\n/
      )

    assert_receive {
      :tcp,
      ^another_client,
      ~s/{"id":1,"job":{"title":"example-job"},"pri":123,"queue":"queue1","status":"ok"}\n/
    }
  end
end
