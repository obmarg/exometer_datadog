defmodule ReporterTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  alias ExometerDatadog.Reporter
  doctest Reporter

  deffixture http_client do
    TestHttpClient.reset
  end

  deffixture metric(http_client, reporter) do
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
    :timer.sleep(35)
    requests = TestHttpClient.requests
    assert length(requests) in 1..2
    initial_requests = length(requests)
    :timer.sleep(20)
    assert length(TestHttpClient.requests) == (initial_requests + 1)
  end

  @tag fixtures: [:metric]
  test "metric payload is correct" do
    :timer.sleep(35)
    [{url, body, headers, _opts} | _] = TestHttpClient.requests
    assert url == "https://app.datadoghq.com/api/v1/series?api_key=ab"
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

  @tag fixtures: [:metric]
  @tag reporter_opts: [host: nil]
  test "uses hostname by default" do
    :timer.sleep(35)
    [{url, body, headers, _opts} | _] = TestHttpClient.requests

    {:ok, expected_host} = :inet.gethostname()

    data = Poison.decode!(body)
    [metric] = data["series"]
    assert metric["host"] == expected_host
  end

  @tag fixtures: [:metric]
  @tag reporter_opts: [host: nil, host_fn: {__MODULE__, :test_host_fn}]
  test "can use a user defined host_fn" do
    :timer.sleep(35)
    [{url, body, headers, _opts} | _] = TestHttpClient.requests

    data = Poison.decode!(body)
    [metric] = data["series"]
    assert metric["host"] == "some_test_host"
  end

  def test_host_fn do
    {:ok, "some_test_host"}
  end

  test "error if api_key not set" do
    assert_raise RuntimeError, fn ->
      Reporter.exometer_init([])
    end
  end
end
