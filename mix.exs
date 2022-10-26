defmodule Couloir42ReverseProxy.MixProject do
  use Mix.Project

  def project do
    [
      app: :couloir42_reverse_proxy,
      version: "0.2.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Couloir42ReverseProxy.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:plug_cowboy, "~> 2.5"},
      {:cowboy_telemetry, "~> 0.4.0"},
      {:reverse_proxy_plug, "~> 2.1"},
      {:httpoison, "~> 1.8"},
      {:mock, "~> 0.3.7", only: :test}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
