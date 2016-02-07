defmodule ExometerDatadog.Reporter do
  @moduledoc """
  An exometer reporter that reports using the datadog rest api

  """
  @behaviour :exometer_report

  require Logger

  defmodule Options do
    @moduledoc false
    # Defines the options that can be passed to the reporter.

    defstruct [api_key: nil,
               app_key: nil,
               host: nil,
               flush_period: 10_000,
               datadog_url: "https://app.datadoghq.com/api/v1",
               http_client: HTTPoison,
               reporter_stats: false]

    @type t :: %Options{api_key: String.t | nil,
                        app_key: String.t | nil,
                        host: String.t | nil,
                        flush_period: integer,
                        datadog_url: String.t,
                        http_client: :atom,
                        reporter_stats: boolean}
  end

  defmodule Point do
    @moduledoc false
    # A single point in a time series to send to datadog

    defstruct [name: nil, value: nil, time: nil]

    @type t :: %Point{name: String.t, value: number, time: number}

    def name(%Point{name: name}), do: name
  end

  defmodule Metric do
    @moduledoc false
    # A single metric batch to send to datadog

    @derive [Poison.Encoder]
    defstruct [metric: nil, points: [], type: "gauge", host: nil]

    @type t :: %Metric{
      metric: String.t,
      points: [{integer, number}],
      type: String.t,
      host: String.t | nil
    }
  end

  @type state :: {Options.t, [Point.t]}

  @spec exometer_init(Keyword.t) :: {:ok, state}
  def exometer_init(opts) do
    opts = struct(Options, opts)

    if opts.api_key == nil or opts.app_key == nil do
      raise "Can't start DatadogReporter with missing api_key & app_key."
    end

    start_flush_timer(opts)
    {:ok, {opts, []}}
  end

  @spec exometer_report([:atom], :atom, any, any, State.t) :: {:ok, State.t}
  def exometer_report(metric, datapoint, extra, value, {opts, points}) do
    name =
      metric
      |> List.insert_at(-1, datapoint)
      |> Enum.map(&to_string/1)
      |> Enum.join(".")

    time = :erlang.system_time(:seconds)

    {:ok, {opts, [%Point{name: name, value: value, time: time} | points]}}
  end

  def exometer_info(:flush, {opts, points}) do
    metrics = for {name, points} <- Enum.group_by(points, &Point.name/1) do
      %Metric{metric: name,
              points: (for p <- points, do: [p.time, p.value]),
              host: opts.host}
    end
    send_to_datadog(opts, metrics)
    start_flush_timer(opts)
    {:ok, {opts, []}}
  end

  # This function will drop any pending points in the reporter.
  # Not intended to be used in production, just for tests
  def exometer_info(:clear, {opts, _points}) do
    {:ok, {opts, []}}
  end

  def exometer_info(unknown, state) do
    {:ok, state}
  end

  def exometer_subscribe(metric, datapoint, extra, interval, state) do
    {:ok, state}
  end

  def exometer_unsubscribe(metric, datapoint, extra, state) do
    {:ok, state}
  end

  def exometer_call(unknown, from, state) do
    {:ok, state}
  end

  def exometer_cast(unknown, state) do
    {:ok, state}
  end

  def exometer_newentry(entry, state) do
    {:ok, state}
  end

  def exometer_setopts(metric, options, status, state) do
    {:ok, state}
  end

  def exometer_terminate(_, _) do
    :ignore
  end

  defp start_flush_timer(%{flush_period: time}) do
    :erlang.send_after(time, self, :flush)
  end

  @spec send_to_datadog(Options.t, [Metric.t]) :: :ok
  defp send_to_datadog(_, []), do: :ok
  defp send_to_datadog(opts, metrics) do
    payload = Poison.encode! %{series: metrics}
    headers = [{"Content-Type", "application/json"}]
    query = URI.encode_query(api_key: opts.api_key,
                             application_key: opts.app_key)
    url = "#{opts.datadog_url}/series?#{query}"

    opts.http_client.post!(url, payload, headers)
  end
end
