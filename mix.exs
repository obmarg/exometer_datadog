defmodule ExometerDatadog.Mixfile do
  use Mix.Project

  def project do
    [app: :exometer_datadog,
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
