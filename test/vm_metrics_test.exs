defmodule VmMetricsTest do
  use ExUnitFixtures
  use ExUnit.Case

  alias ExometerDatadog.Reporter

  deffixture vm_metrics, autouse: true do
    ExometerDatadog.add_vm_metrics

    on_exit fn -> ExometerDatadog.remove_vm_metrics end
  end

  test "can get values of vm metrics" do
    {:ok, _} = :exometer.get_value([:erlang, :memory])
    {:ok, _} = :exometer.get_value([:erlang, :statistics])
  end

  test "registers subscribers" do
    subs = :exometer_report.list_subscriptions(Reporter)
    metric_names = for {name, _, _, _} <- subs, into: MapSet.new, do: name
    assert metric_names == MapSet.new([[:erlang, :memory],
                                       [:erlang, :statistics]])
  end

  test "remove_vm_metrics removes metrics & subscriptions" do
    ExometerDatadog.remove_vm_metrics
    {:error, :not_found} = :exometer.get_value([:erlang, :memory])
    {:error, :not_found} = :exometer.get_value([:erlang, :statistics])
    [] = :exometer_report.list_subscriptions(Reporter)
  end
end
