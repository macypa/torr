defmodule Torr.Crawler do
  require Logger
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, %{})
  end

  def init(state) do
    schedule_work() # Schedule work to be performed at some point
    Process.send_after(self(), :work, 1)
    {:ok, state}
  end

  def doWork() do
    url = "http://zamunda.net/"
#    url = "http://zelka.org/"

    pageListUrl = "#{url}bananas"
#    pageListUrl = "#{url}browse.php"
#    Logger.debug "pageListUrl: #{inspect(pageListUrl)}"
    torrentUrls = collectTorrentUrls(pageListUrl)
#    Logger.debug "torrentUrls: #{inspect(torrentUrls)}"
    Enum.each torrentUrls, fn torrentUrl ->
      torrUrl = "#{url}#{torrentUrl}"
      torrentMap = fetchTorrentData(torrUrl)
#      Logger.debug "torrentMap: #{inspect(torrentMap)}"

      case Torr.Repo.insert(Torr.Torrent.changeset(%Torr.Torrent{}, torrentMap)) do
        {:ok, torrent} ->
          Logger.debug "torrent: #{inspect(torrent)}"
        {:error, changeset} ->
          Logger.debug "can't save torrent with changeset: #{inspect(changeset)}"
      end
    end
#      File.write("body.html", Enum.join(banans, "\n"))
  end

  def collectTorrentUrls(url) do
    banans = Torr.Crawler.download(url)
#    File.write("body.html", Enum.join(banans, "\n"))
    banans = banans |> Floki.find("a")
           |> Floki.attribute("href")
           |> Enum.filter(fn(url) -> String.starts_with?(url, "banan?id=") end)
#           |> Enum.filter(fn(url) -> String.starts_with?(url, "details.php?id=") end)

#    Logger.debug "collectTorrentUrls banans: #{inspect(banans)}"
    banans = for torrUrl <- banans, do: String.replace(torrUrl,  ~r/&hit.*/u, "")

#    File.write("body.html", Enum.join(banans, "\n"))
    banans
  end

  def fetchTorrentData(url) do
    htmlString = download(url)

    name = htmlString |> Floki.find("h1")
                      |> Enum.at(0)
                      |> Floki.text
                      |> String.trim

    htmlTree = htmlString |> Floki.find("h1 ~ table") |> Enum.at(0)
    contentHtml = htmlTree |> Enum.at(0) |> Floki.text

    %{
      url: url,
      name: name,
      html: contentHtml,
      json: Enum.at(htmlTree, 0) # %{}
    }

  end

  def handle_info(:work, state) do
    doWork()

    schedule_work() # Reschedule once more
    {:noreply, state}
  end

  defp schedule_work() do
    Process.send_after(self(), :work, 1 * 60 * 60 * 1000) # In 1 hours
  end


  def download(url) do
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
#    headers = [
#              "Accept-Encoding": "gzip, deflate, sdch",
#              "Accept-Language": "en-US,en;q=0.8",
#              "Upgrade-Insecure-Requests": "1",
#              "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Ubuntu Chromium/53.0.2785.143 Chrome/53.0.2785.143 Safari/537.36",
#              "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
#              "Cache-Control": "max-age=0",
#              "Cookie": "PHPSESSID=km3bv5kllmfl023hsb2hmo2r26; uid=3296682; pass=cf2c4af26d3d19b8ebab768f209152a5",
#              "Connection": "keep-alive"
#            ]
    options = [hackney: [{:follow_redirect, true}]]
    download(url, headers, options)
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
#    File.write("body.html", htmlString)
#    Logger.debug "dwonloaded html: #{inspect(htmlString)}"
    htmlString
  end

  def unzip(body) do
      z = :zlib.open
      :zlib.inflateInit(z, 31)
      res = :zlib.inflate(z, body)
      Enum.join(res, "")
  end
end