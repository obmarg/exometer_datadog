defmodule VmMetricsTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false

  alias ExometerDatadog.Reporter

  deffixture vm_metrics(reporter), autouse: true do
    ExometerDatadog.add_vm_metrics

    on_exit fn -> ExometerDatadog.remove_vm_metrics end
  end

  @expected_metrics [[:erlang, :memory],
                     [:erlang, :statistics],
                     [:erlang, :system_info]]

  test "can get values of vm metrics" do
    for metric <- @expected_metrics do
      {:ok, _} = :exometer.get_value(metric)
    end
  end

  test "registers subscribers" do
    subs = :exometer_report.list_subscriptions(Reporter)
    metric_names = for {name, _, _, _} <- subs, into: MapSet.new, do: name
    assert metric_names == MapSet.new(@expected_metrics)
  end

  test "remove_vm_metrics removes metrics & subscriptions" do
    ExometerDatadog.remove_vm_metrics
    for metric <- @expected_metrics do
      {:error, :not_found} = :exometer.get_value(metric)
    end
    [] = :exometer_report.list_subscriptions(Reporter)
  end
end
