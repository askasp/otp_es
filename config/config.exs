use Mix.Config

config :otp_es,
  nodes: []

import_config "#{Mix.env()}.exs"
