defmodule OtpEs.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  require Logger
  @moduledoc false

  use Application
  alias ExHashRing.HashRing

  def start(_type, _args) do
    result = Application.fetch_env(:otp_es, :nodes)

    nodes =
      with {:ok, nodes} <- result,
      	   a when is_list(a) <- nodes,
           true <- length(a) > 0 do
        a
      else

        _err ->
            Logger.warn("Running on self node, do not cluster!")
            [Node.self()]
      end

    children = [
      {Registry, keys: :unique, name: StreamRegistry},
      {Registry, keys: :unique, name: AggregateRegistry},
      {Phoenix.PubSub, name: :es_pubsub},
      {DynamicSupervisor, strategy: :one_for_one, name: StreamSupervisor},
      {DynamicSupervisor, strategy: :one_for_one, name: AggregateSupervisor}
    ]

    opts = [strategy: :one_for_one, name: OtpEs.Supervisor]
    ring = HashRing.new()

    ring =
      Enum.reduce(nodes, ring, fn node, acc ->
        {:ok, x} = HashRing.add_node(acc, node)
        x
      end)

    FastGlobal.put(:ring, ring)
    Supervisor.start_link(children, opts)
  end
end
