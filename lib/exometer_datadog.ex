defmodule ExometerDatadog do
  @moduledoc """
  An elixir library that integrates exometer & datadog.
  """
  use Application

  alias ExometerDatadog.{Reporter, SystemMetrics}

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
    memory_stats = ~w(atom binary ets processes total)a
    system_stats = ~w(port_count process_count)a

    [:erlang, :memory]
    |> metric_name
    |> new_metric(
      {:function, :erlang, :memory, [], :proplist, memory_stats},
      memory_stats
    )

    [:erlang, :statistics]
    |> metric_name
    |> new_metric(
      {:function, :erlang, :statistics, [:'$dp'], :value, [:run_queue]},
      [:run_queue]
    )

    [:erlang, :system_info]
    |> metric_name
    |> new_metric(
      {:function, :erlang, :system_info, [:'$dp'], :value, system_stats},
      system_stats
    )
  end

  @moduledoc """
  Removes the VM metrics added by `add_vm_metrics/0`
  """
  def remove_vm_metrics do
    metrics = [[:erlang, :memory],
               [:erlang, :statistics],
               [:erlang, :system_info]]
    for metric <- metrics, do: metric |> metric_name |> delete_metric
  end

  @moduledoc """
  This adds system metrics to exometer.

  Currently this uses files located within `/proc` so will only work on linux
  machines.
  """
  def add_system_metrics do
    unless File.exists?("/proc") do
      Logger.warn "Can't find `/proc` - system metrics will mostly be useless."
    end

    load_stats = ~w(1 5 15)a
    new_metric(
      [:system, :load],
      {:function, SystemMetrics, :loadavg, [], :proplist, load_stats},
      load_stats,
      5000
    )

    memory_stats = ~w(total free buffered cached)a
    new_metric(
      [:system, :mem],
      {:function, SystemMetrics, :meminfo, [], :proplist, memory_stats},
      memory_stats,
      5000
    )

    swap_stats = ~w(free total used)a
    new_metric(
      [:system, :swap],
      {:function, SystemMetrics, :swapinfo, [], :proplist, swap_stats},
      swap_stats,
      5000
    )
  end

  @moduledoc """
  Removes the system metrics added by `add_system_metrics/0`
  """
  def remove_system_metrics do
    [[:system, :load], [:system, :mem], [:system, :swap]]
    |> Enum.each(&delete_metric/1)
  end

  defp get_env(key, default \\ nil) do
    Application.get_env(:exometer_datadog, key, default)
  end

  defp metric_name(name) do
    prefix = (get_env(:metric_prefix) || []) |> List.wrap()
    prefix ++ List.wrap(name)
  end

  # Creates a metric in exometer & subscribes our reporter to it.
  defp new_metric(metric_name, metric_def, datapoints, update_freq \\ nil) do
    update_freq = update_freq || get_env(:update_frequency)
    :ok = :exometer.new(metric_name, metric_def)
    :ok = :exometer_report.subscribe(
      Reporter, metric_name, datapoints, update_freq
    )
  end

  # Deletes a metric & removes it's subscription.
  defp delete_metric(metric_name) do
    :exometer.delete(metric_name)
    :exometer_report.unsubscribe_all Reporter, metric_name
  end
end
