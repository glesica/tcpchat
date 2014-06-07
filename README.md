# Tcpchat

A simple, naive, chat server application designed to demonstrate Elixir/Erlang
development patterns and concurrency.

## To build it:

~~~
$ mix escriptize
~~~

## To run it:

~~~
$ ./tcpchat [--port <port>] [--name <name>] [--motd <motd>]
~~~

  * `port` - the port to run on
  * `name` - the server's name
  * `motd` - the server's message of the day

## To use it:

~~~
$ telnet <server> <port>
~~~

The following commands should work:

  * `/join <channel>` - join a channel (`> /join mychannel`)
  * `/part <channel>` - leave a channel (`> /part mychannel`)
  * `/talk <channel> <message>` - say something in a channel (`> /talk mychannel hello there!`)
  * `/motd` - view the message of the day
  * `/nick <name>` - change your user name
  * `/list` - show a list of active channels
