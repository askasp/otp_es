use Mix.Config

config :otp_es,
  nodes: []


config :goth, json: {:system, "GCP_CREDENTIALS"}


import_config "#{Mix.env()}.exs"
