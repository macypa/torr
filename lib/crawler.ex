defmodule Torr.Crawler do
  require Logger
  use GenServer
  alias Torr.Torrent
  alias Torr.Tracker
  alias Torr.Repo

  def start_link do
    GenServer.start_link(__MODULE__, %{})
  end

  def init(state) do
    schedule_work()
    Process.send_after(self(), :work, 1)
    {:ok, state}
  end

  def doWork() do
    trackers = case Repo.all(Tracker) do
      [] ->
        initTrackers()
      trackers -> trackers
    end

    for tracker <- trackers do
      collectTorrentUrls(tracker)
    end
  end

  def fetchTorrentData(tracker, url) do
    htmlString = download(tracker, "#{url}&filelist=1")

    name = htmlString |> Floki.find(tracker.namePattern)
                      |> Enum.at(0)
                      |> Floki.text
                      |> String.trim
                      |> HtmlEntities.decode
    name = :iconv.convert("utf-8", "utf-8", name)

    htmlTree = htmlString |> Floki.find(tracker.htmlPattern)
    contentHtml = htmlTree |> Floki.raw_html |> HtmlEntities.decode
    contentHtml = :iconv.convert("utf-8", "utf-8", contentHtml)

    torrentInfo = %{}
    torrentInfo = contentHtml |> Floki.find(tracker.patterns["torrentDescNameValuePattern"])
                              |> Enum.reduce(torrentInfo, fn x, acc ->
                                    Map.put(acc,
                                            Floki.find(x, tracker.patterns["torrentDescNamePattern"]) |> Floki.text |> String.replace(~r/\n|\r/, ""),
                                            Floki.find(x, tracker.patterns["torrentDescValuePattern"]) |> Floki.text)
                                  end)

    torrentInfo = contentHtml |> Floki.find("#description img")
                              |> Floki.attribute("src")
                              |> Enum.reduce(torrentInfo, fn x, acc ->
                                        value = String.replace(x, ~r/thumbs\//, "")
                                        Map.put(acc, "images", "#{acc["images"]} #{value}")
                                  end)

    torrentInfo = contentHtml |> Floki.find("#youtube_video")
                              |> Floki.attribute("code")
                              |> Enum.reduce(torrentInfo, fn x, acc ->
                                        Map.put(acc, "video", "https://youtu.be/#{x}")
                                  end)

    %{
      url: url,
      name: name,
      html: contentHtml,
      json: torrentInfo
    }

  end

  def collectTorrentUrlsFromPage(tracker, pageNumber) do
    pageUrl = "#{tracker.url}#{tracker.pagePattern}#{pageNumber}"

    urlReg = case Regex.compile(tracker.urlPattern, "u") do
      {:ok, urlRexgex} -> urlRexgex
      {:error, error} -> {:error, error}
    end

    Torr.Crawler.download(tracker, pageUrl) |> Floki.find("a")
            |> Floki.attribute("href")
            |> Enum.filter(fn(torrUrl) -> String.match?(torrUrl, urlReg) end)
            |> Enum.map(fn(torrUrl) -> Regex.named_captures(urlReg, torrUrl)["url"] end)
            |> Enum.uniq
            |> Enum.map(fn(torrUrl) -> Torrent.save(%{pageUrl: pageUrl, url: "#{tracker.url}#{torrUrl}"}) end)
  end

  def collectTorrentUrls(tracker) do
    Logger.info "collectTorrentUrls from: #{tracker.url}#{tracker.pagePattern}#{tracker.lastPageNumber+1}"
    try do
      for _ <- Stream.cycle([:ok]) do
        tracker = Tracker |> Repo.get(tracker.id)
        case collectTorrentUrlsFromPage(tracker, tracker.lastPageNumber+1) do
          [] -> throw :break
          _ ->
                collectTorrents(tracker)
                Tracker.save(%{url: tracker.url, lastPageNumber: tracker.lastPageNumber+1})
        end
      end
    catch
      :break -> :ok
    end
  end

  def collectTorrents(tracker) do
    Torrent
          |> Torrent.allUrlWithEmptyName(tracker.url)
          |> Repo.all
#                  |> Enum.map(fn(torrUrl) -> Regex.named_captures(urlReg, torrUrl)["url"] end)
          |> Enum.each(fn torrentUrls ->
                          Torrent.save(fetchTorrentData(tracker, torrentUrls.url))
                        end)
  end


  def handle_info(:work, state) do
    doWork()

    schedule_work() # Reschedule once more
    {:noreply, state}
  end

  defp schedule_work() do
    Process.send_after(self(), :work, 1 * 60 * 60 * 1000) # In 1 hours
  end

  def download(tracker, url) do
    headers = [
              "Accept-Encoding": "gzip;deflate,sdch",
              "Accept-Language": "en-US,en;q=0.8",
              "Upgrade-Insecure-Requests": "1",
              "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Ubuntu Chromium/53.0.2785.143 Chrome/53.0.2785.143 Safari/537.36",
              "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
              "Referer": tracker.url,
              "Cookie": tracker.cookie,
              "Connection": "keep-alive"
            ]
    options = [hackney: [{:follow_redirect, true}], timeout: :infinity, recv_timeout: :infinity]
    download(url, headers, options)
  end

  def download(url, headers, options) do
    my_future_function = fn ->
      case HTTPoison.get(url, headers, options) do
          {:ok, %HTTPoison.Response{body: body, headers: _headers, status_code: 200}} ->
            unzip(body)
          {:ok, %HTTPoison.Response{body: _body, headers: _headers, status_code: 502}} ->
            Logger.debug "Error: #{url} is 502."
            raise "Error: #{url} is 502."
          {:ok, %HTTPoison.Response{status_code: 404}} ->
            Logger.debug "Error: #{url} is 404."
            raise "Error: #{url} is 404."
          {:error, %HTTPoison.Error{reason: reason}} ->
            Logger.debug "Error: #{url} just ain't workin. reason: #{inspect(reason)}"
            raise "Error: #{url} just ain't workin. reason: #{inspect(reason)}"
          other ->
            Logger.debug "Error: #{url} just ain't workin. reason: #{inspect(other)}"
            raise "Error: #{url} just ain't workin. reason: #{inspect(other)}"
      end
    end
    t = GenRetry.Task.async(my_future_function, retries: :infinity, delay: 5000, jitter: 0.1)
    Task.await(t)  # may raise exception
  end

  def unzip(body) do
      z = :zlib.open
      :zlib.inflateInit(z, 31)
      res = :zlib.inflate(z, body)
      joined = Enum.join(res, "")
      :iconv.convert("windows-1251", "utf-8", joined)
  end

  def initTrackers() do
      [Tracker.save(%{
        url: "http://zamunda.net/",
        name: "zamunda.net",
        lastPageNumber: -1,
        pagePattern: "bananas?sort=6&type=asc&page=",
        urlPattern: "(|javascript)(?<url>banan\\?id=\\d+)",
        namePattern: "h1",
        htmlPattern: "h1 ~ table ~ table",
        cookie: "PHPSESSID=b2en7vbfb02e2a6l86q2l4vsh0; cookieconsent_dismissed=yes; uid=4656705; pass=2e47932cbb4cf7a6bca4766fb98e4c5f; cats=7; periods=7; statuses=1; howmanys=1; a=22; __utmt=1; ismobile=no; swidth=1920; sheight=1055; russian_lang=no; g=m; __utma=100172053.259253342.1483774748.1483988651.1484001975.4; __utmb=100172053.2.10.1484001975; __utmc=100172053; __utmz=100172053.1483774748.1.1.utmcsr=(direct)|utmccn=(direct)|utmcmd=(none)",
        patterns: %{ "torrentDescNameValuePattern": "table > tr", "torrentDescNamePattern": "td.td_newborder[align=right]", "torrentDescValuePattern": "td.td_newborder+td.td_newborder" }
      }) |> elem(1)
#      ,
#      Tracker.save(%{
#        url: "http://zelka.org/",
#        name: "zelka.org",
#        lastPageNumber: -1,
#        pagePattern: "browse.php?sort=6&type=asc&page=",
#        urlPattern: "(|javascript)(?<url>details.php\\?id=\\d+)",
#        namePattern: "h1",
#        htmlPattern: "h1 ~ table ~ table",
#        cookie: "uid=3296682; pass=cf2c4af26d3d19b8ebab768f209152a5",
#        patterns: %{ "torrentDescNameValuePattern": "table > tr", "torrentDescNamePattern": "td.td_newborder[align=right]", "torrentDescValuePattern": "td.td_newborder+td.td_newborder" }
#      }) |> elem(1)
      ]
  end
end