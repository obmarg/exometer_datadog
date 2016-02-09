# ExometerDatadog

An elixir library for integrating for pushing exometer metrics to datadog via
the REST API.

It's already possible to use the existing `exometer_report_statsd` reporter to
feed data in to the dogstatsd agent. However, there are some situations where
that is not ideal (or even possible). This library aims to cover those
situations, by directly submitting exometer statistics to datadog via the REST
API.

It also provides some functionality to make configuring exometer and submitting
common metrics to datadog easier.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add exometer_datadog to your list of dependencies in `mix.exs`:

        def deps do
          [{:exometer_datadog, "~> 0.0.1"}]
        end

  2. Ensure exometer_datadog is started before your application:

        def application do
          [applications: [:exometer_datadog]]
        end

  3. Add your datadog API keys to your configuraton.  Note: you probably want
     to store these in `prod.secret.exs` or equivalent to avoid checking in to
     your repository.

        config :exometer_datadog,
          api_key: 'abcd',
          app_key: 'defg'

  4. You might optionally want to configure some of the other exometer_datadog
     settings. For more details, see the documentation.
