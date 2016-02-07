ExUnit.start()
ExUnitFixtures.start()

defmodule TestHttpClient do
  @ok_resp %{status_code: 200}

  require Logger

  def start() do
    Agent.start(fn -> {@ok_resp, []} end, name: __MODULE__)
  end

  def stop() do
    Agent.stop(__MODULE__)
  end

  def post!(url, body, headers \\ [], options \\ []) do
    Agent.get_and_update(__MODULE__, fn {resp, requests} ->
      new_requests = List.insert_at(requests, -1, {url, body, headers, options})
      {resp, {resp, new_requests}}
    end)
  end

  def set_response(resp) do
    Agent.update(__MODULE__, fn {_, requests} -> {resp, requests} end)
  end

  def requests() do
    Agent.get(__MODULE__, fn {_, requests} -> requests end)
  end
end

