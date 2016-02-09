defmodule ExometerDatadog.Mixfile do
  use Mix.Project

  def project do
    [app: :exometer_datadog,
     version: "0.2.0",
     elixir: "~> 1.2",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps,

     name: "ExometerDatadog",
     source_url: "https://github.com/obmarg/exometer_datadog",
     homepage_url: "https://github.com/obmarg/exometer_datadog",
     docs: [main: "ExometerDatadog"]]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger, :exometer_core],
     mod: {ExometerDatadog, []},
     env: default_config(Mix.env)]
  end

  defp deps do
    [{:exometer_core, github: "PSPDFKit-labs/exometer_core"},
     {:poison, "~> 2.0.0"},

     {:ex_unit_fixtures, "~> 0.3.0", only: :test},

     # Seriously annoying having to include this override, but parse_trans &
     # setup appear to depend on 2 different versions of edown.
     {:edown, git: "git://github.com/uwiger/edown.git", tag: "0.7",
      override: true, optional: true},

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
     report_vm_metrics: false]
  end
end
