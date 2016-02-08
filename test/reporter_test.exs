defmodule ReporterTest do
  use ExUnitFixtures
  use ExUnit.Case
  alias ExometerDatadog.Reporter
  doctest Reporter

  deffixture http_client do
    send Reporter, :clear
    TestHttpClient.reset
  end

  deffixture metric(http_client) do
    :exometer.new([:test], :gauge)
    :exometer.update([:test], 10)
    :exometer_report.subscribe(Reporter, [:test], [:value], 5)

    on_exit fn ->
      :exometer_report.unsubscribe_all(Reporter, [:test])
      :exometer.delete([:test])
    end
  end

  @tag fixtures: [:metric]
  test "metrics are flushed every period" do
    :timer.sleep(45)
    requests = TestHttpClient.requests
    assert length(requests) in 1..2
    initial_requests = length(requests)
    :timer.sleep(20)
    assert length(TestHttpClient.requests) == (initial_requests + 1)
  end

  @tag fixtures: [:metric]
  test "metric payload is correct" do
    :timer.sleep(45)
    [{url, body, headers, _opts} | _] = TestHttpClient.requests
    assert url == "https://app.datadoghq.com/api/v1/series?api_key=ab&application_key=cd"
    assert headers == [{"Content-Type", "application/json"}]

    data = Poison.decode!(body)

    [metric] = data["series"]
    assert metric["metric"] == "test.value"
    assert metric["type"] == "gauge"
    assert metric["host"] == "testhost"
    assert length(metric["points"]) >= 1
    case metric["points"] do
      [[_, x], [_, y] | _] ->
        assert x == 10
        assert y == 10
      [[_, x]] ->
        assert x == 10
    end
  end

  test "error if api_key not set" do
    assert_raise RuntimeError, fn ->
      Reporter.exometer_init(app_key: "ab")
    end
  end

  test "error if app_key not set" do
    assert_raise RuntimeError, fn ->
      Reporter.exometer_init(api_key: "cd")
    end
  end
end
