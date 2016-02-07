defmodule ExometerReportDatadog.Mixfile do
  use Mix.Project

  def project do
    [app: :exometer_report_datadog,
     version: "0.1.0",
     elixir: "~> 1.2",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger, :exometer_core]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [{:exometer_core, github: "PSPDFKit-labs/exometer_core"},
     {:poison, "~> 2.0.0"},

     {:ex_unit_fixtures, "~> 0.3.0", only: :test},

     # Seriously annoying having to include this override, but parse_trans &
     # setup appear to depend on 2 different versions of edown.
     {:edown, git: "git://github.com/uwiger/edown.git", tag: "0.7",
      override: true, optional: true}
    ]
  end
end
