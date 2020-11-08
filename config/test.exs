use Mix.Config

config :otp_es,
  nodes: [:"my-cluster1@127.0.0.1", :"my-cluster2@127.0.0.1", :"my-cluster3@127.0.0.1"]
