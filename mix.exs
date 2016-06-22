defmodule ExometerDatadog.Mixfile do
  use Mix.Project

  def project do
    [
      app: :exometer_datadog,
      version: "0.4.3",
      elixir: "~> 1.2",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps,

      name: "ExometerDatadog",
      source_url: "https://github.com/obmarg/exometer_datadog",
      homepage_url: "https://github.com/obmarg/exometer_datadog",
      docs: [main: "ExometerDatadog"],

      description: description,
      package: package
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger, :exometer_core, :httpoison],
     mod: {ExometerDatadog, []},
     env: default_config(Mix.env)]
  end

  defp deps do
    [{:exometer_core, "~> 1.4.0"},
     {:poison, "~> 2.0"},
     {:httpoison, "~> 0.8.0", optional: true},

     {:ex_unit_fixtures, "~> 0.3.0", only: :test},

     # ExDoc & deps.
     {:earmark, "~> 0.1", only: :dev},
     {:ex_doc, "~> 0.11", only: :dev}
    ]
  end

  defp default_config(_env) do
    [add_reporter: true,
     reporter_config: [],
     update_frequency: 1000,
     metric_prefix: nil,
     report_system_metrics: false,
     report_vm_metrics: false,
     host_fn: {:inet, :gethostname}]
  end

  defp description do
    """
    Integrates exometer with datadog via the datadog REST API.
    """
  end

  defp package do
    [
      maintainers: ["Graeme Coupar"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/obmarg/exometer_datadog"}
    ]
  end
end
