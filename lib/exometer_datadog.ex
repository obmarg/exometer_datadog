defmodule ExometerDatadog do
  @moduledoc """
  A library that integrates exometer with datadog via the datadog REST API.

  It's already possible to use the existing `exometer_report_statsd` reporter to
  feed data in to the dogstatsd agent. However, there are some situations where
  that is not ideal (or even possible). This library aims to cover those
  situations, by directly submitting exometer statistics to datadog via the REST
  API.

  ### Setup

  To pull in ExometerDatadog to your application, you should add it to your
  dependencies and list of applications in `mix.exs`, and then add an `api_key`
  and `app_key` to your configuration.  For example:

      config :exometer_datadog,
         api_key: 'abcd',
         app_key: 'defg'

  You may want to put this in `prod.secret.exs` or similar to avoid checking the
  keys in to your repository.

  Now ExometerDatadog should startup along with your app. For details of what it
  does on startup, see `start/2`.

  ### Configuration

  ExometerDatadog gets it's configuration from the mix config files. It has
  these config settings:

  - `api_key` is the datadog API key to send metrics with.
  - `app_key` is the datadog app key to send metrics with.
  - `host_fn` is a `{module, function}` tuple that specifies a function to be
    called to determine the hostname to report to datadog. Defaults to
    `:inet.gethostname`
  - `host` can be used instead of `host_fn` to hard-code the hostname.
  - `add_reporter` controls whether ExometerDatadog.Reporter will be registered
    on application startup. By default this is true.
  - `report_vm_metrics` controls whether VM metrics will be reported to datadog.
  - `update_frequency` controls the frequency with which VM metrics will be
    updated.
  - `report_system_metrics` controls whether VM metrics will be reported to
    datadog.
  - `metric_prefix` can be provided as a list of atoms to prefix the VM metric names
    with.
  - `reporter_config` can be used to provide config to the reporter. See
    `ExometerDatadog.Reporter` for more details on it's configuration.

  #### Loading Config from environment variables.

  In some cases it might be desirable to load some of the above settings (the
  `api_key` for example) from environment variables. ExometerDatadog supports
  this. Simply set your mix config value to `{:system, "ENV_VAR"}` (where
  "ENV_VAR" is your environment variable name), and ExometerDatadog will read
  from the environment on startup.

  For example, this would cause the api key & app key to be loaded from
  DATADOG_API_KEY & DATADOG_APP_KEY:

      config :exometer_datadog,
        api_key: {:system, "DATADOG_API_KEY"},
        app_key: {:system, "DATADOG_APP_KEY"}

  """
  use Application

  alias ExometerDatadog.{Reporter, SystemMetrics}

  require Logger

  @doc """
  Starts the ExometerDatadog application.

  This will:

  - Register the ExometerDatadog.Reporter with exometer. See
  `register_reporter/1`.
  - Optionally create some VM metrics and subscribe them to the datadog
  reporter.  See `add_vm_metrics/0`.  This is disabled by default.
  - Optionally create some system metrics and subscribe them to the datadog
  reporter.  See `add_system_metrics/0`.  This is disabled by default.
  """
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    have_api_key = reporter_config[:api_key] != nil
    reporter = get_env(:add_reporter)
    if reporter and not have_api_key do
      Logger.warn("ExometerDatadog.Reporter is configured without API key.")
      Logger.warn("The reporter will be disabled.")
    end
    reporter = reporter and have_api_key

    if reporter do
      register_reporter
    else
      if get_env(:report_system_metrics) or get_env(:report_vm_metrics) do
        Logger.warn("Datadog reporter is disabled.")
        Logger.warn("System & VM metrics will also be disabled.")
      end
    end
    if reporter and get_env(:report_system_metrics), do: add_system_metrics
    if reporter and get_env(:report_vm_metrics), do: add_vm_metrics

    children = []

    opts = [strategy: :one_for_one, name: ExometerDatadog.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @doc """
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
    :ok = :exometer_report.add_reporter(Reporter, reporter_config(opts))
  end

  @doc """
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

  @doc false
  # Removes the VM metrics added by `add_vm_metrics/0`
  # Mostly for testing
  def remove_vm_metrics do
    metrics = [[:erlang, :memory],
               [:erlang, :statistics],
               [:erlang, :system_info]]
    for metric <- metrics, do: metric |> metric_name |> delete_metric
  end

  @doc """
  This adds system metrics to exometer.

  Currently this uses files located within `/proc` so will only work on linux
  machines.
  """
  def add_system_metrics do
    unless File.exists?("/proc") do
      Logger.warn "Can't find `/proc` - system metrics will mostly be useless."
    end

    load_stats = SystemMetrics.loadavg |> Keyword.keys
    unless Enum.empty?(load_stats) do
      new_metric(
        [:system, :load],
        {:function, SystemMetrics, :loadavg, [], :proplist, load_stats},
        load_stats,
        5000
      )
    end

    memory_stats = SystemMetrics.meminfo |> Keyword.keys
    unless Enum.empty?(memory_stats) do
      new_metric(
        [:system, :mem],
        {:function, SystemMetrics, :meminfo, [], :proplist, memory_stats},
        memory_stats,
        5000
      )
    end

    swap_stats = SystemMetrics.swapinfo |> Keyword.keys
    unless Enum.empty?(swap_stats) do
      new_metric(
        [:system, :swap],
        {:function, SystemMetrics, :swapinfo, [], :proplist, swap_stats},
        swap_stats,
        5000
      )
    end
  end

  @doc false
  # Removes the system metrics added by `add_system_metrics/0`
  # Mostly for testing
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

  defp extract_env_vars({:system, var_name}) when is_list(var_name) do
    extract_env_vars({:system, var_name |> List.to_string})
  end
  defp extract_env_vars({:system, var_name}) when is_binary(var_name) do
    System.get_env(var_name)
  end
  defp extract_env_vars(var), do: var

  defp reporter_config(opts \\ []) do
    :reporter_config
    |> get_env([])
    |> Keyword.merge(api_key: get_env(:api_key),
                     app_key: get_env(:app_key))
    |> Keyword.merge(opts)
    |> Enum.map(fn {k, v} -> {k, extract_env_vars(v)} end)
  end
end
