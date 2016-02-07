defmodule ExometerDatadog do
  @moduledoc """
  An elixir library that integrates exometer & datadog.
  """
  use Application

  alias ExometerDatadog.Reporter

  require Logger

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    if Application.get_env(:exometer_datadog, :add_reporter) do
      register_reporter
    end

    children = []

    opts = [strategy: :one_for_one, name: ExometerDatadog.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @moduledoc """
  Registers the datadog reporter with exometer.

  This will automatically be done on application startup, but this function is
  provided to allow manual operation as well.

  ### Options

  By default these will be pulled from the exometer_datadog config, however they
  can be overridden here.

  * `api_key` - The datadog API key to use.
  * `app_key` - The datadog app specific API key to use.
  """
  def register_reporter(opts \\ []) do
    reporter_config =
      :reporter_config
      |> get_env([])
      |> Keyword.merge(api_key: get_env(:api_key),
                       app_key: get_env(:app_key))
      |> Keyword.merge(opts)

    :exometer_report.add_reporter(Reporter, reporter_config)
  end

  @moduledoc """
  Creates some exometer metrics that report the status of the VM.

  This will create a number of metrics that report statistics about the VM to
  datadog.
  """
  def add_vm_metrics do
    update_frequency = get_env(:update_frequency)
    memory_stats = ~w(atom binary ets processes total)a

    memory_metric = metric_name([:erlang, :memory])
    :exometer.new(
      memory_metric,
      {:function, :erlang, :memory, [], :proplist, memory_stats}
    )
    :exometer_report.subscribe(
      Reporter, memory_metric, memory_stats, update_frequency
    )
    statistics_metric = metric_name([:erlang, :statistics])
    :exometer.new(
      statistics_metric,
      {:function, :erlang, :statistics, [:'$dp'], :value, [:run_queue]}
    )
    :exometer_report.subscribe(
      Reporter, statistics_metric, :run_queue, update_frequency
    )
  end

  @moduledoc """
  Removes the VM metrics added by `add_vm_metrics/0`
  """
  def remove_vm_metrics do
    for metric <- [[:erlang, :memory], [:erlang, :statistics]] do
      metric = metric_name(metric)
      :exometer.delete(metric)
      :exometer_report.unsubscribe_all Reporter, metric
    end
  end

  defp get_env(key, default \\ nil) do
    Application.get_env(:exometer_datadog, key, default)
  end

  defp metric_name(name) do
    prefix = (get_env(:metric_prefix) || []) |> List.wrap()
    prefix ++ List.wrap(name)
  end
end
