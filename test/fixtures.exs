defmodule ExometerDatadogFixtures do
  use ExUnitFixtures.FixtureModule

  deffixture http_client, scope: :module do
    TestHttpClient.start()

    on_exit fn -> TestHttpClient.stop() end

    TestHttpClient
  end
end
