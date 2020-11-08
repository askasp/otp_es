# OtpEs

## Description
File based eventstore that uses OTP to "guarantee" consistency even
when distributed over multiple nodes.

Each stream is a folder and each event is a file inside the stream folder
named 1.2.3....

A cluster unique agent is setup for each stream, and only that agent
is allowed to append to that stream.  The agent holds the current event number in its
state, and on write requests it verifies this towards the "expected version" parameter.

A [hash_ring](https://github.com/discord/ex_hash_ring) is used to ensure that a
stream always goes to the same node.

A phoenix pubsub is used to broadcast new events.

The nodes that shall have agents are set in the config (see config/test.exs), and to guarantee consistency they
cannot be changed while running.   Its fine to autoscale your app, so long the nodes 
defined are not changed and not scaled out.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `otp_es` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:otp_es, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/otp_es](https://hexdocs.pm/otp_es).

