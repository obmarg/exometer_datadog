defmodule SystemMetricsTest do
  use ExUnitFixtures
  use ExUnit.Case

  alias ExometerDatadog.{Reporter, SystemMetrics}

  deffixture system_metrics, autouse: true do
    ExometerDatadog.add_system_metrics

    on_exit fn -> ExometerDatadog.remove_system_metrics end
  end

  @expected_metrics [[:system, :load]]

  test "can get values of system metrics" do
    for metric <- @expected_metrics do
      {:ok, _} = :exometer.get_value(metric)
    end
  end

  test "registers subscribers" do
    # We won't be subscribed if we don't have a `proc` folder to get results from.
    if File.exists?("/proc") do
      subs = :exometer_report.list_subscriptions(Reporter)
      metric_names = for {name, _, _, _} <- subs, into: MapSet.new, do: name
      assert metric_names == MapSet.new(@expected_metrics)
    end
  end

  test "remove_system_metrics removes metrics & subscriptions" do
    ExometerDatadog.remove_system_metrics
    for metric <- @expected_metrics do
      {:error, :not_found} = :exometer.get_value(metric)
    end
    [] = :exometer_report.list_subscriptions(Reporter)
  end

  test "calling loadavg directly" do
    if File.exists?("/proc/loadavg") do
      keys = SystemMetrics.loadavg |> Keyword.keys
      assert keys == ~w(1 5 15)a
    else
      assert SystemMetrics.loadavg == []
    end
  end

end
