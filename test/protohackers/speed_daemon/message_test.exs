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

  describe "encode/1" do
    test "%M.Error{}" do
      assert <<0x10, 0x03, 0x62, 0x61, 0x64>> = M.encode(%M.Error{msg: "bad"})

      assert <<0x10, 0x0B, 0x69, 0x6C, 0x6C, 0x65, 0x67, 0x61, 0x6C, 0x20, 0x6D, 0x73, 0x67>> =
               M.encode(%M.Error{msg: "illegal msg"})
    end

    test "%M.Ticket{}" do
      assert <<0x21, 0x04, 0x55, 0x4E, 0x31, 0x58, 0x00, 0x42, 0x00, 0x64, 0x00, 0x01, 0xE2, 0x40,
               0x00, 0x6E, 0x00, 0x01, 0xE3, 0xA8, 0x27,
               0x10>> =
               M.encode(%M.Ticket{
                 plate: "UN1X",
                 road: 66,
                 from_mile: 100,
                 from_timestamp: 123_456,
                 to_mile: 110,
                 to_timestamp: 123_816,
                 speed: 10000
               })

      assert <<0x21, 0x07, 0x52, 0x45, 0x30, 0x35, 0x42, 0x4B, 0x47, 0x01, 0x70, 0x04, 0xD2, 0x00,
               0x0F, 0x42, 0x40, 0x04, 0xD3, 0x00, 0x0F, 0x42, 0x7C, 0x17,
               0x70>> =
               M.encode(%M.Ticket{
                 plate: "RE05BKG",
                 road: 368,
                 from_mile: 1234,
                 from_timestamp: 1_000_000,
                 to_mile: 1235,
                 to_timestamp: 1_000_060,
                 speed: 6000
               })
    end

    test "%M.Heartbeat{}" do
      assert <<0x41>> = M.encode(%M.Heartbeat{})
    end
  end
end
