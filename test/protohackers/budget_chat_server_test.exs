defmodule Protohackers.BudgetChatServerTest do
  use ExUnit.Case, async: true

  test "prompts user to ask for a name" do
    {:ok, port} = Protohackers.BudgetChatServer.start_link()

    {:ok, peer_socket} = :gen_tcp.connect(~c/localhost/, port, mode: :binary, active: false)

    assert {:ok, "Welcome to budgetchat! What shall I call you?\n"} =
             :gen_tcp.recv(peer_socket, 0)
  end

  test "lists present user's names in an empty room" do
    {:ok, port} = Protohackers.BudgetChatServer.start_link()

    {:ok, peer_socket} = :gen_tcp.connect(~c/localhost/, port, mode: :binary, active: false)

    {:ok, "Welcome to budgetchat! What shall I call you?\n"} = :gen_tcp.recv(peer_socket, 0)

    :ok = :gen_tcp.send(peer_socket, "alice\n")

    assert {:ok, "* The room contains: \n"} = :gen_tcp.recv(peer_socket, 0)
  end

  test "lists present user's names in a non-empty room" do
    {:ok, port} = Protohackers.BudgetChatServer.start_link()

    {:ok, alice_socket} = :gen_tcp.connect(~c/localhost/, port, mode: :binary, active: false)
    {:ok, "Welcome to budgetchat! What shall I call you?\n"} = :gen_tcp.recv(alice_socket, 0)
    :ok = :gen_tcp.send(alice_socket, "alice\n")

    {:ok, bob_socket} = :gen_tcp.connect(~c/localhost/, port, mode: :binary, active: false)
    {:ok, "Welcome to budgetchat! What shall I call you?\n"} = :gen_tcp.recv(bob_socket, 0)
    :ok = :gen_tcp.send(bob_socket, "bob\n")

    assert {:ok, "* The room contains: alice\n"} = :gen_tcp.recv(bob_socket, 0)
  end

  test "announces a new user joins" do
    {:ok, port} = Protohackers.BudgetChatServer.start_link()

    {:ok, alice_socket} = :gen_tcp.connect(~c/localhost/, port, mode: :binary, active: false)
    {:ok, "Welcome to budgetchat! What shall I call you?\n"} = :gen_tcp.recv(alice_socket, 0)
    :ok = :gen_tcp.send(alice_socket, "alice\n")
    {:ok, "* The room contains: \n"} = :gen_tcp.recv(alice_socket, 0)

    {:ok, bob_socket} = :gen_tcp.connect(~c/localhost/, port, mode: :binary, active: false)
    {:ok, "Welcome to budgetchat! What shall I call you?\n"} = :gen_tcp.recv(bob_socket, 0)
    :ok = :gen_tcp.send(bob_socket, "bob\n")

    assert {:ok, "* bob has entered the room\n"} = :gen_tcp.recv(alice_socket, 0)
  end

  test "announces a user leaves" do
    {:ok, port} = Protohackers.BudgetChatServer.start_link()

    {:ok, alice_socket} = :gen_tcp.connect(~c/localhost/, port, mode: :binary, active: false)
    {:ok, "Welcome to budgetchat! What shall I call you?\n"} = :gen_tcp.recv(alice_socket, 0)
    :ok = :gen_tcp.send(alice_socket, "alice\n")
    {:ok, "* The room contains: \n"} = :gen_tcp.recv(alice_socket, 0)

    {:ok, bob_socket} = :gen_tcp.connect(~c/localhost/, port, mode: :binary, active: false)
    {:ok, "Welcome to budgetchat! What shall I call you?\n"} = :gen_tcp.recv(bob_socket, 0)
    :ok = :gen_tcp.send(bob_socket, "bob\n")

    {:ok, "* bob has entered the room\n"} = :gen_tcp.recv(alice_socket, 0)

    :gen_tcp.close(bob_socket)

    assert {:ok, "* bob has left the room\n"} = :gen_tcp.recv(alice_socket, 0)
  end

  test "chat" do
    {:ok, port} = Protohackers.BudgetChatServer.start_link()

    {:ok, alice_socket} = :gen_tcp.connect(~c/localhost/, port, mode: :binary, active: false)
    {:ok, "Welcome to budgetchat! What shall I call you?\n"} = :gen_tcp.recv(alice_socket, 0)
    :ok = :gen_tcp.send(alice_socket, "alice\n")
    {:ok, "* The room contains: \n"} = :gen_tcp.recv(alice_socket, 0)

    {:ok, bob_socket} = :gen_tcp.connect(~c/localhost/, port, mode: :binary, active: false)
    {:ok, "Welcome to budgetchat! What shall I call you?\n"} = :gen_tcp.recv(bob_socket, 0)
    :ok = :gen_tcp.send(bob_socket, "bob\n")

    {:ok, "* bob has entered the room\n"} = :gen_tcp.recv(alice_socket, 0)

    :gen_tcp.send(bob_socket, "Hi!\n")

    assert {:ok, "[bob] Hi!\n"} = :gen_tcp.recv(alice_socket, 0)
  end

  test "duplicate username" do
    {:ok, port} = Protohackers.BudgetChatServer.start_link()

    {:ok, alice_socket1} = :gen_tcp.connect(~c/localhost/, port, mode: :binary, active: false)
    {:ok, "Welcome to budgetchat! What shall I call you?\n"} = :gen_tcp.recv(alice_socket1, 0)
    :ok = :gen_tcp.send(alice_socket1, "alice\n")

    {:ok, alice_socket2} = :gen_tcp.connect(~c/localhost/, port, mode: :binary, active: false)
    {:ok, "Welcome to budgetchat! What shall I call you?\n"} = :gen_tcp.recv(alice_socket2, 0)
    :ok = :gen_tcp.send(alice_socket2, "alice\n")

    assert {:error, :closed} = :gen_tcp.recv(alice_socket2, 0)
  end

  test "invalid username" do
    {:ok, port} = Protohackers.BudgetChatServer.start_link()

    {:ok, alice_socket1} = :gen_tcp.connect(~c/localhost/, port, mode: :binary, active: false)
    {:ok, "Welcome to budgetchat! What shall I call you?\n"} = :gen_tcp.recv(alice_socket1, 0)
    :ok = :gen_tcp.send(alice_socket1, "爱丽丝\n")

    assert {:error, :closed} = :gen_tcp.recv(alice_socket1, 0)
  end

  test "does not send chat messages to clients that haven't joined" do
    {:ok, port} = Protohackers.BudgetChatServer.start_link()

    {:ok, alice_socket1} = :gen_tcp.connect(~c/localhost/, port, mode: :binary, active: false)
    {:ok, "Welcome to budgetchat! What shall I call you?\n"} = :gen_tcp.recv(alice_socket1, 0)
    :ok = :gen_tcp.send(alice_socket1, "alice\n")

    {:ok, alice_socket2} = :gen_tcp.connect(~c/localhost/, port, mode: :binary, active: false)
    {:ok, "Welcome to budgetchat! What shall I call you?\n"} = :gen_tcp.recv(alice_socket2, 0)

    :ok = :gen_tcp.send(alice_socket1, "Hi!\n")

    assert {:error, :timeout} = :gen_tcp.recv(alice_socket2, 0, 1000)
  end
end
