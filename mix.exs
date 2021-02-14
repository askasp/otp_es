defmodule OtpEs.MixProject do
  use Mix.Project

  def project do
    [
      app: :otp_es,
      version: "0.1.0",
      elixir: "~> 1.11.3",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: [
        test: "test --no-start"
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {OtpEs.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:google_api_storage, "~> 0.26"},
      # {:dep_from_hexpm, "~> 0.3.0"},
      {:goth, "~> 1.2.0"},
      {:jason, "~> 1.2.2"},
      {:tesla, "~> 1.4.0"},
      {:ex_hash_ring, "~> 3.0"},
      {:phoenix_pubsub, "~> 2.0.0"},
      {:local_cluster, "~> 1.2", only: [:test]},
      {:fastglobal, "~> 1.0"}
    ]
  end
end
