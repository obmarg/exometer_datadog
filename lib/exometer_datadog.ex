defmodule ExometerDatadog do
  @moduledoc """
  An elixir library that integrates exometer & datadog.
  """
  use Application

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

    :exometer_report.add_reporter(ExometerDatadog.Reporter, reporter_config)
  end

  defp get_env(key, default \\ nil) do
    Application.get_env(:exometer_datadog, key, default)
  end
end
