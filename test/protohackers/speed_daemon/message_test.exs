defmodule Protohackers.SpeedDaemon.MessageTest do
  use ExUnit.Case, async: true

  alias Protohackers.SpeedDaemon.Message, as: M

  describe "decode/1" do
    test "{:ok, %M.Observation{}}" do
      assert {
               :ok,
               %M.Observation{
                 plate: "UN1X",
                 timestamp: 1000
               },
               ""
             } = M.decode(<<0x20, 0x04, 0x55, 0x4E, 0x31, 0x58, 0x00, 0x00, 0x03, 0xE8>>)

      assert {
               :ok,
               %M.Observation{
                 plate: "RE05BKG",
                 timestamp: 123_456
               },
               ""
             } =
               M.decode(
                 <<0x20, 0x07, 0x52, 0x45, 0x30, 0x35, 0x42, 0x4B, 0x47, 0x00, 0x01, 0xE2, 0x40>>
               )
    end

    test "{:ok, %M.WantHeartBeat{}}" do
      assert {:ok, %M.WantHeartBeat{interval: 10}, ""} =
               M.decode(<<0x40, 0x00, 0x00, 0x00, 0x0A>>)

      assert {:ok, %M.WantHeartBeat{interval: 1243}, ""} =
               M.decode(<<0x40, 0x00, 0x00, 0x04, 0xDB>>)
    end

    test "{:ok, %M.IAmCamera{}}" do
      assert {:ok, %M.IAmCamera{road: 66, mile: 100, limit: 60}, ""} =
               M.decode(<<0x80, 0x00, 0x42, 0x00, 0x64, 0x00, 0x3C>>)

      assert {:ok, %M.IAmCamera{road: 368, mile: 1234, limit: 40}, ""} =
               M.decode(<<0x80, 0x01, 0x70, 0x04, 0xD2, 0x00, 0x28>>)
    end

    test "{:ok, %M.IAmDispatcher{}}" do
      assert {:ok, %M.IAmDispatcher{roads: [66]}, ""} = M.decode(<<0x81, 0x01, 0x00, 0x42>>)

      assert {:ok, %M.IAmDispatcher{roads: [66, 368, 5000]}, ""} =
               M.decode(<<0x81, 0x03, 0x00, 0x42, 0x01, 0x70, 0x13, 0x88>>)
    end
  end
end
