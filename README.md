# Tcpchat

A simple, naive, chat server application designed to demonstrate Elixir/Erlang
development patterns and concurrency.

Right now to run it just do:

    $ elixir -r lib/tcpchat.ex -e 'Tcpchat.Server.start(3000, "myserver",
    "welcome to the server!")'
