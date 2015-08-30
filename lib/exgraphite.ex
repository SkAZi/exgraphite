defmodule ExGraphite do
    use Application

    @metrics Application.get_env(:exgraphite, :metrics, []) 
                |> Enum.map(fn({m,l})-> {m, Enum.into(l, %{})} end)
    @metrics_keys Keyword.keys(@metrics)

    def start(_type, _args) do
        import Supervisor.Spec, warn: false

        create_metrics()

        children = [
            worker(ExGraphite.Worker, [])
        ]

        opts = [strategy: :one_for_one, name: ExGraphite.Supervisor, max_restarts: 50000, max_seconds: 10]
        Supervisor.start_link(children, opts)
    end

    def create_metrics(metrics \\ @metrics) do
        Enum.each(metrics, fn({metric, opts = %{type: type}})-> 
            case type do
                :counter -> 
                    :folsom_metrics.new_counter(metric)
                :meter -> 
                    :folsom_metrics.new_meter(metric)
                :gauge -> 
                    :folsom_metrics.new_gauge(metric)
                :histogram -> 
                    :folsom_metrics.new_histogram(metric, :slide, opts[:window] || 60)
            end
        end)
    end

    def all(), do: Keyword.keys(:folsom_metrics.get_metrics_info)

    def log(metrics, value) when metrics in @metrics_keys do
        case :folsom_metrics.get_metric_info(metrics)[metrics][:type] do
            nil -> nil
            :counter -> :folsom_metrics.notify({metrics, {:inc, value}})
            _ -> :folsom_metrics.notify({metrics, value})
        end
    end
    def log(_, _), do: nil

end
