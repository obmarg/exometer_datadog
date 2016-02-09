defmodule ExometerDatadog.SystemMetrics do
  @moduledoc """
  Gets the load averages of the system.

  Only works on linux with access to /proc/loadavg.
  """
  def loadavg do
    res =
      with {:ok, data} <- read_file("/proc/loadavg"),
           [one, five, fifteen | _] <- String.split(data, " "),
           {one, ""} <- Float.parse(one),
           {five, ""} <- Float.parse(five),
           {fifteen, ""} <- Float.parse(fifteen),
           do: ["1": one, "5": five, "15": fifteen]

    if Keyword.keyword?(res), do: res, else: []
  end

  def meminfo do
    read_meminfo %{
      "MemTotal:" => :total,
      "MemFree:" => :free,
      "Buffers:" => :buffered,
      "Cached:" => :cached,
    }
  end

  # We can't use File.read because it doesn't work with /proc files. (Mostly
  # becaues it calls stat on them, sees they have 0 size and returns that
  # accordingly)
  defp read_file(filename) do
    with {:ok, file} <- File.open(filename),
         data = IO.binread(file, :all),
         :ok <- File.close(file),
         do: {:ok, data}
  end

  # Reads data from /proc/meminfo.  Extracts stats specified in mem_stats
  defp read_meminfo(mem_stats) do
    case read_file("/proc/meminfo") do
      {:ok, data} ->
        stats = data |> String.split(~r/\s+/) |> Stream.chunk(3, 3, [])
        for [stat, count, unit] <- stats, Map.has_key?(mem_stats, stat) do
          {mem_stats[stat], convert_to_bytes(count, unit)}
        end
      _ ->
        []
    end
  end

  # Converts a count into some
  defp convert_to_bytes(count, unit) when is_binary(count) do
    {count, ""} = Integer.parse(count)
    convert_to_bytes(count, unit)
  end
  defp convert_to_bytes(count, "B"), do: count
  defp convert_to_bytes(count, "kB"), do: count * 1024
  defp convert_to_bytes(count, "mB"), do: count * 1024 * 1024
  defp convert_to_bytes(count, "gB"), do: count * 1024 * 1024 * 1024
end
