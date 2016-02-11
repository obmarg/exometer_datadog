defmodule ExometerDatadogFixtures do
  use ExUnitFixtures.FixtureModule

  alias ExometerDatadog.Reporter

  deffixture reporter(context) do
    [flush_period: 20, host: "testhost", http_client: TestHttpClient,
     api_key: "ab", app_key: "cd"]
    |> Keyword.merge(context[:reporter_opts] || [])
    |> ExometerDatadog.register_reporter()

    # Give the reporter time to startup.
    :timer.sleep(50)

    on_exit fn ->
      :ok = :exometer_report.remove_reporter(Reporter)
    end
  end
end
