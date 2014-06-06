defmodule Tcpchat do

  def main(args) do
    {switches, params, _} = args |> parse_args

    port = Keyword.get(switches, :port, 3000)
    name = Keyword.get(switches, :name, "tcpchat_server")
    motd = Keyword.get(switches, :motd, "Welcome to Tcpchat server!")

    Tcpchat.Server.start(port, name, motd)
  end

  defp parse_args(args) do
    OptionParser.parse(args,
      switches: [port: :integer, name: :string, motd: :string],
      aliases: [p: :port, n: :name, m: :motd])
  end

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
      ["/nick", nick] ->
        {:nick, nick}
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
