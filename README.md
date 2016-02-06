# ExometerReportDatadog

An exometer reporter for reporting directly to datadog.

It's already possible (possibly even recommended?) to use the existing
`exometer_report_statsd` reporter to feed data in to the dogstatsd agent.
However, there are some situations where that is not ideal (or even possible).
This plugin aims to cover those situations, by directly submitting exometer
statistics to datadog via the REST API.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add exometer_report_datadog to your list of dependencies in `mix.exs`:

        def deps do
          [{:exometer_report_datadog, "~> 0.0.1"}]
        end

  2. Ensure exometer_report_datadog is started before your application:

        def application do
          [applications: [:exometer_report_datadog]]
        end

