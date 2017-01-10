defmodule Torr.Crawler do
  require Logger
  use GenServer

  use GenServer

    def start_link do
      GenServer.start_link(__MODULE__, %{})
    end

    def init(state) do
      schedule_work() # Schedule work to be performed at some point
      Process.send_after(self(), :work, 1)
      {:ok, state}
    end

    def handle_info(:work, state) do
      url = "http://zamunda.net/bananas"
      headers = [
                 "Accept-Encoding": "gzip;deflate,sdch",
                 "Accept-Language": "en-US,en;q=0.8",
                 "Upgrade-Insecure-Requests": "1",
                 "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Ubuntu Chromium/53.0.2785.143 Chrome/53.0.2785.143 Safari/537.36",
                 "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
                 "Referer": "http://zamunda.net/",
                 "Cookie": "PHPSESSID=b2en7vbfb02e2a6l86q2l4vsh0; cookieconsent_dismissed=yes; uid=4656705; pass=2e47932cbb4cf7a6bca4766fb98e4c5f; cats=7; periods=7; statuses=1; howmanys=1; a=22; __utmt=1; ismobile=no; swidth=1920; sheight=1055; russian_lang=no; g=m; __utma=100172053.259253342.1483774748.1483988651.1484001975.4; __utmb=100172053.2.10.1484001975; __utmc=100172053; __utmz=100172053.1483774748.1.1.utmcsr=(direct)|utmccn=(direct)|utmcmd=(none)",
                 "Connection": "keep-alive"
                 ]
      options = [hackney: [{:follow_redirect, true}]]

      htmlString = download(url, headers, options)


      schedule_work() # Reschedule once more
      {:noreply, state}
    end

    defp schedule_work() do
      Process.send_after(self(), :work, 1 * 60 * 60 * 1000) # In 1 hours
    end


    def download(url, headers, options) do
      htmlString = case HTTPoison.get(url, headers, options) do
        {:ok, %HTTPoison.Response{body: body, headers: _headers, status_code: 200}} ->
            unzip(body)
        {:ok, %HTTPoison.Response{status_code: 404}} ->
          IO.puts "Error: #{url} is 404."
          nil
        {:error, %HTTPoison.Error{reason: _}} ->
          IO.puts "Error: #{url} just ain't workin."
          nil
      end
#      File.write("html.zip", html)
      Logger.debug "dwonloaded html: #{inspect(htmlString)}"
      htmlString
    end

    def unzip(body) do
        z = :zlib.open
        :zlib.inflateInit(z, 31)
#        :zlib.inflate(z, body)
        :zlib.inflate(z, body)
    end
end