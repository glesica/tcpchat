# Tcpchat

A simple, naive, chat server application designed to demonstrate Elixir/Erlang
development patterns and concurrency.

To build it:

~~~
$ mix escriptize
~~~

To run it:

~~~
$ ./tcpchat [--port <port>] [--name <name>] [--motd <motd>]
~~~

  * `port` - the port to run on
  * `name` - the server's name
  * `motd` - the server's message of the day
