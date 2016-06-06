defmodule ExometerDatadog.Reporter do
  @moduledoc """
  An exometer reporter that reports metrics using the datadog rest api.

  ### Usage

  ExometerDatadog will automatically register this reporter with exometer on
  startup, provided the :add_reporter config setting is true. You can also call
  `ExometerDatadog.register_reporter/1` yourself to do this.

  However, `ExometerDatadog.Reporter` is just a normal exometer reporter plugin,
  so you can also register it yourself using the exometer config or
  `:exometer_report.add_reporter/2` if you want.

  ### Options

  ExometerDatadog.Reporter accepts the following options:

  - `api_key` is the API key to send metrics with.
  - `host_fn` is a {module, function} tuple that will be called to determine the
    current hostname to pass to datadog.  Should return an {:ok, hostname} tuple.
  - `host` is the host to pass to datadog, this can be used to override
    `host_fn`
  - `flush_period` is the number of MS we will wait between sending metrics to
    datadog. Any metrics reported in this time will be stored and sent at the
    same time.
  - `global_tags` should be a list of tags to be added to every metric we
    send to datadog. It should be a keyword list or a list of strings in datadog
    tag format.

  Many of these are also in the application config. ExometerDatadog will take
  care of passing them to the Reporter when it creates it.
  """
  @behaviour :exometer_report

  require Logger

  defmodule Options do
    @moduledoc false
    # Defines the options that can be passed to the reporter.

    defstruct [api_key: nil,
               host: nil,
               host_fn: nil,
               flush_period: 10_000,
               datadog_url: "https://app.datadoghq.com/api/v1",
               http_client: HTTPoison,
               global_tags: []]

    @type t :: %Options{api_key: String.t | nil,
                        host: String.t | nil,
                        host_fn: {:atom, :atom} | nil,
                        flush_period: integer,
                        datadog_url: String.t,
                        http_client: :atom,
                        global_tags: [String.t]}
  end

  defmodule Point do
    @moduledoc false
    # A single point in a time series to send to datadog

    defstruct [name: nil, value: nil, time: nil, tags: []]

    @type t :: %Point{
      name: String.t,
      value: number,
      time: number,
      tags: [String.t]
    }
  end

  defmodule Metric do
    @moduledoc false
    # A single metric batch to send to datadog

    @derive [Poison.Encoder]
    defstruct [metric: nil, points: [], type: "gauge", host: nil, tags: []]

    @type t :: %Metric{
      metric: String.t,
      points: [{integer, number}],
      type: String.t,
      host: String.t | nil,
      tags: [String.t]
    }
  end

  @typep state :: {Options.t, [Point.t]}

  @doc false
  @spec exometer_init(Keyword.t) :: {:ok, state}
  def exometer_init(opts) do
    opts = Keyword.update(opts, :global_tags, [], &tags_to_strings/1)
    opts = struct(Options, opts)

    if opts.api_key == nil do
      raise "Can't start DatadogReporter with missing api_key."
    end

    {host_fn_mod, host_fn_fun} =
      opts.host_fn || Application.get_env(:exometer_datadog, :host_fn)

    host = cond do
      opts.host -> opts.host
      host = Application.get_env(:exometer_datadog, :host) -> host
      true ->
        {:ok, host} = :erlang.apply(host_fn_mod, host_fn_fun, [])
        host
    end

    opts = %{opts | host: host}

    start_flush_timer(opts)
    {:ok, {opts, []}}
  end

  @doc false
  @spec exometer_report([:atom], :atom, any, any, State.t) :: {:ok, State.t}
  def exometer_report(metric, datapoint, _extra, value, {opts, points}) do
    name =
      metric
      |> List.insert_at(-1, datapoint)
      |> Enum.map(&to_string/1)
      |> Enum.join(".")

    time = :erlang.system_time(:seconds)

    {:ok, {opts, [%Point{name: name, value: value, time: time} | points]}}
  end

  @doc false
  def exometer_info(:flush, {opts, points}) do
    metrics = for {{name, tags}, points} <- group_points(points) do
      %Metric{metric: name,
              points: (for p <- points, do: [p.time, p.value]),
              host: opts.host,
              tags: tags ++ opts.global_tags}
    end

    send_to_datadog(opts, metrics)
    start_flush_timer(opts)
    {:ok, {opts, []}}
  end

  def exometer_info(_unknown, state) do
    {:ok, state}
  end

  @doc false
  def exometer_subscribe(_metric, _datapoint, _extra, _interval, state) do
    {:ok, state}
  end

  @doc false
  def exometer_unsubscribe(_metric, _datapoint, _extra, state) do
    {:ok, state}
  end

  @doc false
  def exometer_call(_unknown, _from, state) do
    {:ok, state}
  end

  @doc false
  def exometer_cast(_unknown, state) do
    {:ok, state}
  end

  @doc false
  def exometer_newentry(_entry, state) do
    {:ok, state}
  end

  @doc false
  def exometer_setopts(_metric, _options, _status, state) do
    {:ok, state}
  end

  @doc false
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
    query = URI.encode_query(api_key: opts.api_key)
    url = "#{opts.datadog_url}/series?#{query}"

    opts.http_client.post!(url, payload, headers)
  end

  @spec group_points([Point.t]) :: %{{String.t, [String.t]} => Point.t}
  defp group_points(points) do
    Enum.group_by(points, fn %{name: name, tags: tags} -> {name, tags} end)
  end

  @spec tags_to_strings(Keyword.t | [String.t]) :: [String.t]
  defp tags_to_strings([]), do: []
  defp tags_to_strings([str | rest]) when is_binary(str) do
    [str | tags_to_strings(rest)]
  end

  defp tags_to_strings([{key, val} | rest]) do
    ["#{key}:#{val}" | tags_to_strings(rest)]
  end
end
