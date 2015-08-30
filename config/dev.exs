use Mix.Config

config :exgraphite, 
    refresh: :timer.seconds(30),
    metrics: []