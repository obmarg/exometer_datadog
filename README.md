# ExometerDatadog

An elixir library for integrating for pushing exometer metrics to datadog via
the REST API.

It's already possible to use the existing `exometer_report_statsd` reporter to
feed data in to the dogstatsd agent. However, there are some situations where
that is not ideal (or even possible). This library aims to cover those
situations, by directly submitting exometer statistics to datadog via the REST
API.

## Features

- Contains an exometer reporter that reports to the datadog API.
- Automatically registers the reporter with exometer.
- Can automatically add VM monitoring stats to exometer.
- Can automatically add limited system monitoring stats that mimic the metrics
  gathered dogstatsd

## Installation

  1. Add exometer_datadog to your list of dependencies in `mix.exs`:

     ```elixir
      def deps do
        [{:exometer_datadog, "~> 0.4.0"}]
      end
     ```

  2. Ensure exometer_datadog is started before your application:

      ```elixir
      def application do
        [applications: [:exometer_datadog]]
      end
      ```

  3. Add your datadog API keys to your configuraton.  Note: you probably want
     to store these in `prod.secret.exs` or equivalent to avoid checking in to
     your repository.  See the docs for more configuration options.

     ```elixir
        config :exometer_datadog,
          api_key: 'abcd',
     ```

  4. You might optionally want to configure some of the other exometer_datadog
     settings. For more details, see the documentation.
