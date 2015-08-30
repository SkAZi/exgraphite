defmodule ExGraphite.Worker do
    
    require Logger
    @suffix Application.get_env(:exgraphite, :suffix, "")
    @metrics Application.get_env(:exgraphite, :metrics, []) |> Enum.map(fn({m,l})-> {m, Enum.into(l, %{})} end)
    @refresh Application.get_env(:exgraphite, :refresh, :timer.seconds(5)) 
    @token Application.get_env(:exgraphite, :token, "")

    def start_link(opts \\ []) do 
        :gen_server.start_link({ :local, __MODULE__ }, __MODULE__, [], []) 
    end

    def init(_) do
        Logger.info "Graphite worker started"
        {:ok, port} = :gen_udp.open(0, [:binary])
        {msec, sec, _} = :erlang.now()
        {:ok, %{port: port, tick: now()}, @refresh}
    end

    def handle_info(:timeout, state=%{port: port, tick: tick}) do
        Enum.each(@metrics, fn
            ({m, %{type: :histogram, values: vals}})->
                data = :folsom_metrics.get_histogram_statistics(m)
                Enum.each(vals, fn(v)-> 
                    value = case v do
                        :count -> 
                            :folsom_metrics.get_metric_value(m) |> Enum.sum
                        _ -> 
                            data[v]
                    end
                    write(m, :"histogram_#{v}", value, port)
                end)

            ({m, %{type: :meter}}) ->
                value = :folsom_metrics.get_metric_value(m)[:mean]
                write(m, :meter, value, port)

            ({m, %{type: :counter, window: w}}) ->
                value = :folsom_metrics.get_metric_value(m)
                write(m, :meter, value, port)

                drop = cond do
                    is_integer(w) -> w == 0 or rem(tick, w) == 0
                    w == :hour -> hour_switched()
                    w == :day -> day_switched()
                    w == :month -> month_switched()
                end

                if drop, do: :folsom_metrics.notify({m, {:dec, value}})

            ({m, %{type: t}}) ->
                value = :folsom_metrics.get_metric_value(m)
                write(m, t, value, port)
        end)

        {:noreply, %{state | tick: tick+1}, @refresh}
    end

    def now() do
        {msec, sec, _} = :erlang.now()
        msec * 1000 * 1000 + sec
    end

    def hour_switched() do
        {d,{h,m,s}} = :calendar.now_to_local_time(:erlang.now)
        {_, {_,m,s}} = :calendar.time_difference({d, {h,0,0}}, {d,{h,m,s}})
        m * 60 + s < @refresh
    end

    def day_switched() do
        {d,t} = :calendar.now_to_local_time(:erlang.now)
        {_, {h,m,s}} = :calendar.time_difference({d, {4,0,0}}, {d,t})
        h * 3600 + m * 60 + s < @refresh
    end

    def month_switched() do
        {{y,m,d},t} = :calendar.now_to_local_time(:erlang.now)
        {_,{h,m,s}} = :calendar.time_difference({{y,m,0},{0,0,0}}, {{y,m,d},t})
        h * 3600 + m * 60 + s < @refresh
    end

    def write(metric, type, value, port) do
        data = "#{@token}.#{metric}_#{type}_#{@suffix} #{value}"
        case @token do
            "" -> Logger.info data
            _ -> :ok = :gen_udp.send(port, 'carbon.hostedgraphite.com', 2003, data)
        end
    end
end
