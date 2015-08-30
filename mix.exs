defmodule ExGraphite.Mixfile do
  use Mix.Project

  def project do
    [app: :exgraphite,
     version: "0.0.1",
     elixir: "~> 1.0.0",
     deps: deps]
  end


  def application do
    [applications: [:logger, :folsom],
     mod: {ExGraphite, []}]
  end


  defp deps do
    [
      {:folsom, github: "boundary/folsom"},
    ]
  end
end
