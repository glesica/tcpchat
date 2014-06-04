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
