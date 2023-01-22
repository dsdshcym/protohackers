defmodule Protohackers.SpeedDaemon.Repository.InMemoryTest do
  use ExUnit.Case, async: true

  test "query(repo, :tickets, filters)" do
    empty_repo = Protohackers.SpeedDaemon.Repository.InMemory.new()

    assert [] = Protohackers.SpeedDaemon.Repository.query(empty_repo, :tickets, [])

    {:ok, repo_with_one_camera} =
      Protohackers.SpeedDaemon.Repository.add(empty_repo, :camera, %{
        road: 123,
        mile: 0,
        limit: 60
      })

    assert [] = Protohackers.SpeedDaemon.Repository.query(repo_with_one_camera, :tickets, [])

    {:ok, repo_with_two_cameras} =
      Protohackers.SpeedDaemon.Repository.add(repo_with_one_camera, :camera, %{
        road: 123,
        mile: 60,
        limit: 60
      })

    assert [] = Protohackers.SpeedDaemon.Repository.query(repo_with_two_cameras, :tickets, [])

    {:ok, repo_with_one_observation} =
      Protohackers.SpeedDaemon.Repository.add(repo_with_two_cameras, :observation, %{
        road: 123,
        camera_mile: 0,
        plate: "abcd",
        timestamp: 3600
      })

    assert [] = Protohackers.SpeedDaemon.Repository.query(repo_with_one_observation, :tickets)

    {:ok, repo_with_two_observations} =
      Protohackers.SpeedDaemon.Repository.add(repo_with_one_observation, :observation, %{
        road: 123,
        camera_mile: 60,
        plate: "abcd",
        timestamp: 10_800
      })

    assert [] = Protohackers.SpeedDaemon.Repository.query(repo_with_two_observations, :tickets)

    {:ok, repo_with_three_observations} =
      Protohackers.SpeedDaemon.Repository.add(repo_with_two_observations, :observation, %{
        road: 123,
        camera_mile: 0,
        plate: "abcd",
        timestamp: 14_400
      })

    assert [
             %{
               plate: "abcd",
               road: 123,
               from_mile: 60,
               from_timestamp: 10_800,
               to_mile: 0,
               to_timestamp: 14_400,
               speed: 6000
             }
           ] = Protohackers.SpeedDaemon.Repository.query(repo_with_three_observations, :tickets)
  end
end
