# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# Disable lagers error logging, as it seems to crash when faced with a map.
config :lager, error_logger_redirect: false

if Mix.env == :test do
  config :exometer_datadog, [
    api_key: "ab",
    app_key: "cd",
    reporter_config: [flush_period: 20,
                      host: "testhost",
                      http_client: TestHttpClient]
  ]
end
