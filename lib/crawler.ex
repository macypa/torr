defmodule Torr.Crawler do
  require Logger
  use GenServer
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

    for tracker <- trackers do
#      Torr.Torrent.save(tracker, processTorrentData(tracker, 85421))
      processTorrents(tracker)
    end
    Logger.info "Crawler done"
  end

  def processTorrents(tracker) do
    Logger.info "processTorrents: #{inspect(tracker)}"
    case tracker.url do
          _ -> Torr.ZamundaTorrent.notProcessed(tracker)
#                                  |> Repo.preload([:tracker])
                                  |> Repo.all
                                  |> Enum.each(fn torrentDBId ->
                                            case tracker.url do
                                              _ ->
                                                    data = processTorrentData(tracker, torrentDBId)
                                                    Torr.Torrent.save(tracker, data)
                                            end
                                   end)
        end
  end

  def processTorrentData(tracker, torrentDBId) do
    case tracker.url do
      _ ->
            torrent = Torr.ZamundaTorrent |> Torr.Repo.get(torrentDBId)

            %{
              name: torrent.name,
              tracker_id: tracker.id,
              torrent_id: torrent.torrent_id,
              json: updateJson(torrent.content_html, tracker)
            }
    end
  end

  def fetchTorrentData(tracker, torrent_id) do
    torrent_info_url = tracker.patterns["torrent_info_url"]
    Logger.debug "collectTorrent from: #{tracker.url}#{torrent_info_url}#{torrent_id}&filelist=1"
    htmlString = download(tracker, "#{tracker.url}#{torrent_info_url}#{torrent_id}&filelist=1")

    name = htmlString |> Floki.find(tracker.namePattern)
                      |> Enum.at(0)
                      |> Floki.text
                      |> String.trim
                      |> HtmlEntities.decode
    name = :iconv.convert("utf-8", "utf-8", name)

    htmlTree = htmlString |> Floki.find(tracker.htmlPattern)
    contentHtml = htmlTree |> Floki.raw_html |> HtmlEntities.decode
    contentHtml = :iconv.convert("utf-8", "utf-8", contentHtml)

    %{
      name: name,
      tracker_id: tracker.id,
      torrent_id: torrent_id,
      content_html: contentHtml,
#      json: updateJson(contentHtml, tracker)
    }
  end

  def updateJson(contentHtml, tracker) do

    torrentInfo = %{}
    torrentInfo = contentHtml |> Floki.find(tracker.patterns["torrentDescNameValuePattern"])
                              |> Enum.reduce(torrentInfo, fn x, acc ->
                                    Map.put(acc,
                                            Floki.find(x, tracker.patterns["torrentDescNamePattern"]) |> Floki.text |> String.replace(~r/\n|\r/, ""),
                                            Floki.find(x, tracker.patterns["torrentDescValuePattern"]) |> Floki.text)
                                  end)

    torrentInfo = Map.put(torrentInfo, "images", getImages(contentHtml, tracker))
    torrentInfo = Map.put(torrentInfo, "video", getVideos(contentHtml, tracker))

    torrentInfo
  end

  def getImages(contentHtml, tracker) do

    imgReg = case Regex.compile(tracker.patterns["imgFilterPattern"], "u") do
      {:ok, imgRexgex} -> imgRexgex
      {:error, error} -> {:error, error}
    end

#    imgLinkReg = case Regex.compile(tracker.patterns["imgLinkPattern"], "u") do
#      {:ok, imgRexgex} -> imgRexgex
#      {:error, error} -> {:error, error}
#    end

    contentHtml |> Floki.find(tracker.patterns["imgSelector"])
                          |> Floki.attribute(tracker.patterns["imgAttrPattern"])
                          |> Enum.filter(fn(imgUrl) -> not String.match?(imgUrl, imgReg) end)
                          |> Enum.uniq
  end

  def getVideos(contentHtml, tracker) do
    contentHtml |> Floki.find(tracker.patterns["videoSelector"])
                              |> Floki.attribute(tracker.patterns["videoAttrPattern"])
#                              |> Enum.reduce(torrentInfo, fn x, acc ->
#                                        Map.put(acc, "video", "https://www.youtube.com/embed/#{x}")
#                                  end)

  end

  def collectTorrentUrlsFromPage(tracker, pageNumber) do
    pageUrl = "#{tracker.url}#{tracker.pagePattern}#{pageNumber}"
    Logger.info "collectTorrentUrlsFromPage from: #{pageUrl}"

    urlReg = case Regex.compile(tracker.urlPattern, "u") do
      {:ok, urlRexgex} -> urlRexgex
      {:error, error} -> {:error, error}
    end

    banans = Torr.Crawler.download(tracker, pageUrl) |> Floki.find("a")
            |> Floki.attribute("href")
            |> Enum.filter(fn(torrUrl) -> String.match?(torrUrl, urlReg) end)
            |> Enum.map(fn(torrUrl) -> Regex.named_captures(urlReg, torrUrl)["url"] end)
            |> Enum.uniq

    case banans do
      [] -> throw :break
      _ -> banans
            |> Enum.map(fn(torrUrl) ->
                            case tracker.url do
                              _ -> Torr.ZamundaTorrent.save(%{tracker_id: tracker.id, page: pageNumber, torrent_id: torrUrl})

                            end
                         end)
    end
  end

  def collectTorrentUrls(tracker) do
    try do
      for _ <- Stream.cycle([:ok]) do
        tracker = Tracker |> Repo.get(tracker.id)
        if tracker.pagesAtOnce > 0 do
          Enum.each(1..tracker.pagesAtOnce, &(collectTorrentUrlsFromPage(tracker, tracker.lastPageNumber+&1)))
          collectTorrents(tracker)
          Tracker.save(%{url: tracker.url, lastPageNumber: tracker.lastPageNumber+tracker.pagesAtOnce})
        end
      end
    rescue
      e -> Logger.error "collectTorrentUrls error: #{inspect(e)}"
            e
    catch
      :break -> :ok
      e -> e
    end
  end

  def collectTorrents(tracker) do
    case tracker.url do
      _ -> Torr.ZamundaTorrent.allWithEmptyName()
                |> Repo.all
      #                  |> Enum.map(fn(torrUrl) -> Regex.named_captures(urlReg, torrUrl)["url"] end)
                |> Enum.each(fn torrent ->
                                case tracker.url do
                                  _ -> Torr.ZamundaTorrent.save(fetchTorrentData(tracker, torrent.torrent_id))
                                end
                              end)
    end

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
    download(tracker.delayOnFail, url, headers, options)
  end

  def download(delay, url, headers, options) do
    my_future_function = fn ->
      case HTTPoison.get(url, headers, options) do
          {:ok, %HTTPoison.Response{body: body, headers: _headers, status_code: 200}} ->
            unzip(body)
          {:ok, %HTTPoison.Response{body: _body, headers: _headers, status_code: 502}} ->
            Logger.error "Error: #{url} is 502."
            raise "Error: #{url} is 502."
          {:ok, %HTTPoison.Response{status_code: 404}} ->
            Logger.error "Error: #{url} is 404."
            raise "Error: #{url} is 404."
          {:error, %HTTPoison.Error{reason: reason}} ->
            Logger.error "Error: #{url} just ain't workin. reason: #{inspect(reason)}"
            raise "Error: #{url} just ain't workin. reason: #{inspect(reason)}"
          other ->
            Logger.error "Error: #{url} just ain't workin. reason: #{inspect(other)}"
            raise "Error: #{url} just ain't workin. reason: #{inspect(other)}"
      end
    end
    t = GenRetry.Task.async(my_future_function, retries: :infinity, delay: delay, jitter: 0.1)
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
        pagesAtOnce: 1,
        delayOnFail: 1000,
        pagePattern: "bananas?sort=6&type=asc&page=",
        urlPattern: "(|javascript)banan\\?id=(?<url>\\d+)",
        namePattern: "h1",
        htmlPattern: "h1 ~ table ~ table",
        cookie: "PHPSESSID=b2en7vbfb02e2a6l86q2l4vsh0; cookieconsent_dismissed=yes; uid=4656705; pass=2e47932cbb4cf7a6bca4766fb98e4c5f; cats=7; periods=7; statuses=1; howmanys=1; a=22; __utmt=1; ismobile=no; swidth=1920; sheight=1055; russian_lang=no; g=m; __utma=100172053.259253342.1483774748.1483988651.1484001975.4; __utmb=100172053.2.10.1484001975; __utmc=100172053; __utmz=100172053.1483774748.1.1.utmcsr=(direct)|utmccn=(direct)|utmcmd=(none)",
        patterns: %{ "torrentDescNameValuePattern": "table > tr",
                      "torrentDescNamePattern": "td.td_newborder[align=right]",
                      "torrentDescValuePattern": "td.td_newborder+td.td_newborder",
                      "imgSelector": "#description img",
                      "imgAttrPattern": "src",
                      "imgLinkPattern": "previewimg.php",
                      "imgFilterPattern": ".*(fullr.png|halfr.png|blankr.png).*",
                      "videoSelector": "#youtube_video",
                      "videoAttrPattern": "code",
                      "torrent_info_url": "banan?id="}
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