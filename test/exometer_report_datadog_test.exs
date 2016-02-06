defmodule ExometerReportDatadogTest do
  use ExUnitFixtures
  use ExUnit.Case
  doctest ExometerReportDatadog

  defmodule TestHttpClient do
    @ok_resp %{status_code: 200}

    require Logger

    def start() do
      Agent.start(fn -> {@ok_resp, []} end, name: __MODULE__)
    end

    def stop() do
      Agent.stop(__MODULE__)
    end

    def post!(url, body, headers \\ [], options \\ []) do
      Agent.get_and_update(__MODULE__, fn {resp, requests} ->
        new_requests = List.insert_at(requests, -1, {url, body, headers, options})
        {resp, {resp, new_requests}}
      end)
    end

    def set_response(resp) do
      Agent.update(__MODULE__, fn {_, requests} -> {resp, requests} end)
    end

    def requests() do
      Agent.get(__MODULE__, fn {_, requests} -> requests end)
    end
  end

  deffixture http_client do
    TestHttpClient.start()

    on_exit fn -> TestHttpClient.stop() end

    TestHttpClient
  end

  deffixture reporter(http_client) do
    :exometer_report.add_reporter(
      ExometerReportDatadog,
      api_key: "ab", app_key: "cd", flush_period: 20,
      http_client: http_client
    )

    on_exit fn -> :exometer_report.remove_reporter(ExometerReportDatadog) end
  end

  deffixture metric(reporter) do
    :exometer.new([:test], :gauge)
    :exometer.update([:test], 10)
    :exometer_report.subscribe(ExometerReportDatadog, [:test], [:value], 5)

    on_exit fn -> :exometer.delete([:test]) end
  end

  @tag fixtures: [:metric]
  test "metrics are flushed every period" do
    :timer.sleep(40)
    requests = TestHttpClient.requests
    assert length(requests) == 1
    :timer.sleep(20)
    assert length(TestHttpClient.requests) == 2
  end

  @tag fixtures: [:metric]
  test "metric payload is correct" do
    :timer.sleep(40)
    [{url, body, headers, _opts}] = TestHttpClient.requests
    assert url == "https://app.datadoghq.com/api/v1/series?api_key=ab&application_key=cd"
    assert headers == [{"Content-Type", "application/json"}]

    data = Poison.decode!(body)

    [metric] = data["series"]
    assert metric["metric"] == "test.value"
    assert metric["type"] == "gauge"
    assert length(metric["points"]) >= 2
    [[_, x], [_, y] | _] = metric["points"]
    assert x == 10
    assert y == 10
  end

  test "error if api_key not set" do
    assert_raise RuntimeError, fn ->
      ExometerReportDatadog.exometer_init(app_key: "ab")
    end
  end

  test "error if app_key not set" do
    assert_raise RuntimeError, fn ->
      ExometerReportDatadog.exometer_init(api_key: "cd")
    end
  end

end
