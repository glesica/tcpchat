defmodule Tcpchat do

  @doc "Parse a raw chat command straight off the socket."
  def parse_cmd(cmd) do
    import String, only: [split: 2, strip: 1]
    import Enum, only: [join: 2]
    tokens = cmd |> strip |> split(" ")
    case tokens do
      ["/join", chan] ->
        {:join, chan}
      ["/part", chan] ->
        {:part, chan}
      ["/talk", chan | msg_parts] ->
        {:talk, chan, msg_parts |> join(" ")}
      ["/motd"] ->
        {:motd}
      ["/motd" | msg_parts] ->
        {:motd, msg_parts |> join(" ")}
      _ ->
        {:error, :syntax}
    end
  end

  @doc "Return help information about the available commands."
  def cmd_help() do
    """
    Available commands:
    /join <channel> - join a channel
    /part <channel> - leave a channel
    /talk <channel> <message> - send a message to a channel
    /motd - view the server message of the day
    """
  end

end

defmodule Tcpchat.Server do

  def start(port, server_name, server_motd) when is_integer(port) do
    server_pid = spawn(fn -> server_handler(server_name, server_motd, %{}) end)
    listen(port, server_pid)
  end

  defp listen(port, server_pid) when is_integer(port) do
    tcp_opts = [:list, {:packet, 0}, {:active, :once}, {:reuseaddr, true}]
    {:ok, listen_socket} = :gen_tcp.listen(port, tcp_opts)
    listen(listen_socket, server_pid)
  end

  defp listen(listen_socket, server_pid) when is_port(listen_socket) do
    listen(listen_socket, 0, server_pid)
  end

  defp listen(listen_socket, counter, server_pid) do
    {:ok, socket} = :gen_tcp.accept(listen_socket)
    user_pid = spawn(fn -> Tcpchat.User.user_handler(socket, counter, server_pid) end)
    # Assign the user process as the owner of its socket
    :gen_tcp.controlling_process(socket, user_pid)
    listen(listen_socket, counter + 1, server_pid)
  end

  # Server handler - provides a global queue and a way to maintain state for
  # the entire server including a global list of available channels and the
  # server's name and MOTD. Provides a proxy for commands from users that might
  # alter the global state of the server.

  defp server_handler(server_name, server_motd, channels) do
    import Map, only: [keys: 1, put: 3]
    receive do
      {:join, chan_name, user={_, _}} ->
        chan_pid = if chan_name in keys(channels) do
          channels[chan_name]
        else
          # Channel doesn't yet exist, create it
          spawn(fn -> Tcpchat.Channel.channel_handler(chan_name, "", %{}) end)
        end
        send(chan_pid, {:join, user})
        server_handler(server_name, server_motd, put(channels, chan_name, chan_pid))

      {:part, chan_name, user={_, _}} ->
        chan_pid = channels[chan_name]
        send(chan_pid, {:part, user})
        server_handler(server_name, server_motd, channels)

      {:motd, {_, user_pid}} ->
        send(user_pid, {:motd, {server_name, server_motd}})
        server_handler(server_name, server_motd, channels)

      {:motd, motd, {_, user_pid}} ->
        send(user_pid, {:motd, {server_name, motd}})
        server_handler(server_name, motd, channels)
    end
  end

end

defmodule Tcpchat.User do

  # User handler - one for each user connected to the system, handles all
  # incoming and outgoing messages for that user and tracks the user's name and
  # list of active channels.

  def user_handler(socket, counter, server_pid) do
    user_name = "user_#{counter}"
    user_handler(socket, user_name, %{}, server_pid)
  end

  defp user_handler(socket, user_name, channels, server_pid) do
    import Map, only: [put: 3, keys: 1, delete: 2]
    import Enum, only: [each: 2]
    import String, only: [from_char_data!: 1, strip: 1]
    receive do
      {:joined, {from_chan_name, from_chan_pid}} when is_pid(from_chan_pid) ->
        :gen_tcp.send(socket, "#{from_chan_name}> *** You have joined the channel ***\n")
        user_handler(socket, user_name, put(channels, from_chan_name, from_chan_pid), server_pid)

      {:joined, {from_chan_name, from_user_name}} ->
        :gen_tcp.send(socket, "#{from_chan_name}> *** #{from_user_name} has joined the channel ***\n")
        user_handler(socket, user_name, channels, server_pid)

      {:parted, {from_chan_name}} ->
        :gen_tcp.send(socket, "#{from_chan_name}> *** You have left the channel ***\n")
        user_handler(socket, user_name, delete(channels, from_chan_name), server_pid)

      {:parted, {from_chan_name, from_user_name}} ->
        :gen_tcp.send(socket, "#{from_chan_name}> *** #{from_user_name} has left the channel ***\n")
        user_handler(socket, user_name, channels, server_pid)

      {:talked, {from_chan_name, from_user_name, message}} ->
        :gen_tcp.send(socket, "#{from_chan_name}> #{from_user_name}: #{message}\n")
        user_handler(socket, user_name, channels, server_pid)

      {:motd, {server_name, server_motd}} ->
        :gen_tcp.send(socket, "*** #{server_name}: #{server_motd} ***\n")
        user_handler(socket, user_name, channels, server_pid)

      {_, _, command} ->
        str_cmd = command |> from_char_data! |> strip
        IO.puts("Received command #{str_cmd} from user #{user_name}")
        case Tcpchat.parse_cmd(str_cmd) do
          {:join, chan_name} ->
            send(server_pid, {:join, chan_name, {user_name, self()}})
          {:part, chan_name} ->
            send(server_pid, {:part, chan_name, {user_name, self()}})
          {:talk, chan_name, message} ->
            send(channels[chan_name], {:talk, {user_name, message}})
          {:motd} ->
            send(server_pid, {:motd, {user_name, self()}})
          {:motd, motd} ->
            send(server_pid, {:motd, motd, {user_name, self()}})
          {:error, :syntax} ->
            :gen_tcp.send(socket, "ERROR: Invalid command (#{str_cmd})\n")
            :gen_tcp.send(socket, Tcpchat.cmd_help())
        end
        :inet.setopts(socket, [{:active, :once}])
        user_handler(socket, user_name, channels, server_pid)

      {:error, :closed} ->
        IO.puts("User #{user_name} has closed the connection")
        # The user closed the connection, part all channels and finish
        each(keys(channels), fn chan_name ->
          send(server_pid, {:part, chan_name, {user_name, self()}})
        end)
    end
  end

end

defmodule Tcpchat.Channel do

  # Channel handler - one for each channel in the system, handles all
  # communication within the channel as well as channel state like the channel
  # name and topic. Once created, will never be destroyed.

  def channel_handler(chan_name, chan_topic, users) do
    import Enum, only: [each: 2]
    import Map, only: [put: 3, delete: 2]
    receive do
      {:join, {user_name, user_pid}} ->
        send(user_pid, {:joined, {chan_name, self()}})
        each(users, fn {_, pid} -> send(pid, {:joined, {chan_name, user_name}}) end)
        channel_handler(chan_name, chan_topic, put(users, user_name, user_pid))

      {:part, {user_name, user_pid}} ->
        send(user_pid, {:parted, {chan_name}})
        new_users = delete(users, user_name)
        each(new_users, fn {_, pid} -> send(pid, {:parted, {chan_name, user_name}}) end)
        channel_handler(chan_name, chan_topic, new_users)

      {:talk, {user_name, message}} ->
        each(users, fn {_, pid} -> send(pid, {:talked, {chan_name, user_name, message}}) end)
        channel_handler(chan_name, chan_topic, users)
    end
  end

end
