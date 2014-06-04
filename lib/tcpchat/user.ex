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

      # TODO this pattern doesn't match
      {:error, :closed} ->
        IO.puts("User #{user_name} has closed the connection")
        # The user closed the connection, part all channels and finish
        each(keys(channels), fn chan_name ->
          send(server_pid, {:part, chan_name, {user_name, self()}})
        end)
    end
  end

end