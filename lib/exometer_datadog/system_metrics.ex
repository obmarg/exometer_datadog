defmodule ExometerDatadog.SystemMetrics do
  # Gets the load average.
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

  # We can't use File.read because it doesn't work with /proc files. (Mostly
  # becaues it calls stat on them, sees they have 0 size and returns that
  # accordingly)
  defp read_file(filename) do
    with {:ok, file} <- File.open(filename),
         data = IO.binread(file, :all),
         :ok <- File.close(file),
         do: {:ok, data}
  end
end
