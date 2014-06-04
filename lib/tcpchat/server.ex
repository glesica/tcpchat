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
