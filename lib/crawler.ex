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
    trackers = case Torr.Repo.all(Torr.Tracker) do
      [] ->
        initTrackers()
      trackers -> trackers
    end

    for tracker <- trackers do
      collectTorrentUrls(tracker)
    end

    for tracker <- trackers do
      processTorrents(tracker)
    end
    Logger.info "Crawler done"
  end

  def processTorrents(tracker) do
    Logger.info "processTorrents: #{inspect(tracker)}"
    try do
        for _ <- Stream.cycle([:ok]) do
          case tracker.url do
            _ -> notProcessed = Torr.ZamundaTorrent.notProcessed(tracker)
#                                  |> Repo.preload([:tracker])
                          |> Repo.all

                 case notProcessed do
                      [] -> throw :break
                      notProcessed -> notProcessed |> Enum.each(fn torrentDBId ->
                                                        case tracker.url do
                                                          _ ->
                                                                data = processTorrentData(tracker, torrentDBId)
                                                                Torr.Torrent.save(tracker, data)
                                                        end
                                                      end)
                 end
          end
        end
      rescue
        e -> Logger.error "processTorrents error: #{inspect(e)}"
              e
      catch
        :break -> :ok
        e -> e
      end

  end

  def processTorrentData(tracker, torrentDBId) do
    case tracker.url do
      _ -> 
            torrent = Torr.ZamundaTorrent |> Torr.Repo.get(torrentDBId)

            Logger.info "processTorrentData id: #{inspect(torrent.id)}"
            %{
              name: torrent.name,
              tracker_id: tracker.id,
              torrent_id: torrent.torrent_id,
              json: updateJson(torrent.content_html, tracker)
            }
    end
  end

  def updateJson(contentHtml, tracker) do

    torrentInfo = %{}
    torrentInfo = contentHtml |> Floki.find(tracker.patterns["torrentDescNameValuePattern"])
                              |> Enum.reduce(torrentInfo, fn x, acc ->
                                    Map.put(acc,
                                            Floki.find(x, tracker.patterns["torrentDescNamePattern"]) |> Floki.text |> String.replace(~r/\n|\r/, ""),
                                            Floki.find(x, tracker.patterns["torrentDescValuePattern"]) |> Floki.text)
                                  end)

    images = getImages(contentHtml, tracker)
    torrentInfo = Map.put(torrentInfo, "images", images)

    torrentInfo = if is_nil(images) or images == [] or String.contains?(torrentInfo["Type"], "XXX") do
      Map.put(torrentInfo, "imagesHidden", getHiddenImages(contentHtml, tracker))
    else
      torrentInfo
    end

    torrentInfo = Map.put(torrentInfo, "video", getVideos(contentHtml, tracker))

    torrentInfo
  end

  def getImages(contentHtml, tracker) do

    imgReg = case Regex.compile(tracker.patterns["imgFilterPattern"], "u") do
      {:ok, imgRexgex} -> imgRexgex
      {:error, error} -> {:error, error}
    end

    images = contentHtml |> Floki.find(tracker.patterns["imgSelector"])
                          |> Floki.attribute(tracker.patterns["imgAttrPattern"])
                          |> Enum.filter(fn(imgUrl) -> not String.match?(imgUrl, imgReg) end)
                          |> Enum.uniq

      Logger.debug "getImages images: #{images}"
    images
  end

  def getHiddenImages(contentHtml, tracker) do

    imgLinkReg = case Regex.compile(tracker.patterns["imgLinkPattern"], "u") do
      {:ok, imgRexgex} -> imgRexgex
      {:error, error} -> {:error, error}
    end

    imgHiddenLinkReg = case Regex.compile(tracker.patterns["imgHiddenPattern"], "u") do
      {:ok, imgRexgex} -> imgRexgex
      {:error, error} -> {:error, error}
    end

    imgReg = case Regex.compile(tracker.patterns["imgFilterPattern"], "u") do
      {:ok, imgRexgex} -> imgRexgex
      {:error, error} -> {:error, error}
    end

    imagesLink = contentHtml |> Floki.find("a")
                              |> Floki.attribute("href")
                              |> Enum.filter(fn(imgUrl) -> String.match?(imgUrl, imgLinkReg) end)

    if is_nil(imagesLink) or imagesLink == [] do
      imgReg = case Regex.compile(tracker.patterns["imgFilterPattern"], "u") do
            {:ok, imgRexgex} -> imgRexgex
            {:error, error} -> {:error, error}
          end

      contentHtml |> Floki.find("a")
                            |> Floki.attribute("href")
                            |> Enum.filter(fn(imgUrl) -> not String.match?(imgUrl, imgReg) end)
                            |> Enum.uniq

    else
      imagePreviewLink = unless String.contains?(imagesLink|> Enum.at(0), tracker.url) do
        "#{tracker.url}#{imagesLink|> Enum.at(0)}"
      else
        imagesLink|> Enum.at(0)
      end
      Logger.debug "getHiddenImages imagePreviewLink: #{imagePreviewLink}"
      linksContent = download(tracker, imagePreviewLink)
                        |> Floki.find(tracker.patterns["imgHiddenSelector"])

      images = linksContent |> Floki.find("img")
                                            |> Floki.attribute(tracker.patterns["imgAttrPattern"])
                                            |> Enum.filter(fn(imgUrl) -> not String.match?(imgUrl, imgReg) end)
                                            |> Enum.uniq

      moreImages = linksContent
                   |> Floki.attribute(tracker.patterns["imgHiddenAttr"])
                   |> Enum.filter(fn(imgUrl) -> String.match?(imgUrl, imgHiddenLinkReg) end)
                   |> Enum.map(fn(imgUrl) -> Regex.named_captures(imgHiddenLinkReg, imgUrl)["url"] end)
                   |> Enum.uniq

      images ++ moreImages |> Enum.uniq
    end
  end

  def getVideos(contentHtml, tracker) do
    contentHtml |> Floki.find(tracker.patterns["videoSelector"])
                              |> Floki.attribute(tracker.patterns["videoAttrPattern"])
#                              |> Enum.reduce(torrentInfo, fn x, acc ->
#                                        Map.put(acc, "video", "https://www.youtube.com/embed/#{x}")
#                                  end)

  end

  def collectTorrentUrlsFromPage(tracker, pageNumber) do
    try do
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
        banans -> banans
                        |> Enum.map(fn(torrUrl) ->
                              case tracker.url do
                                _ -> Torr.ZamundaTorrent.save(%{tracker_id: tracker.id, page: pageNumber, torrent_id: torrUrl})

                              end
                           end)
      end
    rescue
      _ -> throw :break
    catch
      _ -> throw :break
    end
  end

  def collectTorrentUrls(tracker) do
    try do
      for _ <- Stream.cycle([:ok]) do
        tracker = Tracker |> Repo.get(tracker.id)
        if tracker.pagesAtOnce > 0 do
          Enum.each(0..tracker.pagesAtOnce, &(collectTorrentUrlsFromPage(tracker, tracker.lastPageNumber+&1)))
          collectTorrents(tracker)
          Tracker.save(%{url: tracker.url, lastPageNumber: tracker.lastPageNumber+tracker.pagesAtOnce})
        end
      end
    rescue
      e -> e
    catch
      :break -> collectTorrents(tracker)
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
                                  _ ->  torrData = fetchTorrentData(tracker, torrent.torrent_id)
                                        case torrData do
                                          nil -> Logger.error "torrent #{torrent.torrent_id} is missing: #{inspect(torrData)}"
                                          change -> Torr.ZamundaTorrent.save(change)
                                        end
                                end
                              end)
    end
  end

  def test() do
    tracker = Torr.Repo.get(Torr.Tracker, 1)
    url = "http://zamunda.net/banan?id=366750&filelist=1"
    content = Torr.Crawler.download(tracker, url)
    pattern = tracker.namePattern
#    pattern = tracker.htmlPattern

    Torr.Crawler.runPattern(content, pattern)

  end

  def fetchTorrentData(tracker, torrent_id) do
    Logger.info "collectTorrent from: #{tracker.url}#{tracker.infoUrl}#{torrent_id}&filelist=1"
    htmlString = download(tracker, "#{tracker.url}#{tracker.infoUrl}#{torrent_id}&filelist=1")
#    Logger.info "fetchTorrentData htmlString : #{htmlString}"

    name = htmlString |> runPattern(tracker.namePattern)
    case name do
      nil -> nil
      [] -> nil
      "" -> nil
      name -> name = name |> Floki.text

              contentHtml = htmlString |> runPattern(tracker.htmlPattern)
              contentHtml = :iconv.convert("utf-8", "utf-8", contentHtml)

              contentHtml = case String.contains?(contentHtml, ">Type</") do
                true -> contentHtml
                false -> :iconv.convert("utf-8", "utf-8", htmlString)
              end

              %{
                name: name,
                tracker_id: tracker.id,
                torrent_id: torrent_id,
                content_html: contentHtml,
          #      json: updateJson(contentHtml, tracker)
              }
    end
  end

  def runPattern(content, pattern) do
    result = if String.starts_with?(pattern, "~r/") do
      regex = Regex.split(~r{~r/(?<reg>.*)/.*$}, pattern, on: [:reg], include_captures: true)
      reg = case Regex.compile(Enum.at(regex, 1), Enum.at(regex, 2) |> String.slice(1..-1)) do
        {:ok, regex} -> regex
        {:error, error} -> {:error, error}
      end

      case Regex.run(reg, content) do
        nil -> [""]
        res -> res
      end
    else
      content |> Floki.find(pattern) |> Floki.raw_html
    end

    result = result |> Floki.raw_html
                    |> String.trim
                    |> HtmlEntities.decode

    result = :iconv.convert("utf-8", "utf-8", result)
    result
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
    options = [connect_timeout: 1000000, timeout: 1000000, recv_timeout: 1000000, hackney: [{:follow_redirect, true}]]
    download(tracker.delayOnFail, url, headers, options)
  end

  def download(delay, url, headers, options) do
    my_future_function = fn ->
      case HTTPoison.get(url, headers, options) do
          {:ok, %HTTPoison.Response{body: body, headers: headers, status_code: 200}} ->
            unzip(body, headers)
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
    Task.await(t, 1000000)  # may raise exception
  end

  def unzip(body, headers) do
#      z = :zlib.open
#      :zlib.inflateInit(z, 31)
#      res = :zlib.inflate(z, body)
#      joined = Enum.join(res, "")

      gzipped = Enum.any?(headers, fn (kv) ->
        case kv do
          {"Content-Encoding", "gzip"} -> true
          _ -> false
        end
      end)

      # body is an Elixir string
      decompressed = if gzipped do
        :zlib.gunzip(body)
      else
        body
      end
      :iconv.convert("windows-1251", "utf-8", decompressed)
  end

  def initTrackers() do
      [Tracker.save(%{
        url: "http://zamunda.net/",
        name: "zamunda.net",
        lastPageNumber: 0,
        pagesAtOnce: 1,
        delayOnFail: 1000,
        pagePattern: "bananas?sort=6&type=asc&page=",
        infoUrl: "banan?id=",
        urlPattern: "(|javascript)banan\\?id=(?<url>\\d+)",
#        htmlPattern: "h1",
        namePattern: "~r/<h1.*?<\/h1>/su",
#        htmlPattern: "h1 ~ table",
        htmlPattern: "~r/<h1.*?(?!Add|Show)\s*comment.*?<\/table>|<h1.*$/su",
        cookie: "PHPSESSID=b2en7vbfb02e2a6l86q2l4vsh0; cookieconsent_dismissed=yes; uid=4656705; pass=2e47932cbb4cf7a6bca4766fb98e4c5f; cats=7; periods=7; statuses=1; howmanys=1; a=22; __utmt=1; ismobile=no; swidth=1920; sheight=1055; russian_lang=no; g=m; __utma=100172053.259253342.1483774748.1483988651.1484001975.4; __utmb=100172053.2.10.1484001975; __utmc=100172053; __utmz=100172053.1483774748.1.1.utmcsr=(direct)|utmccn=(direct)|utmcmd=(none)",
        patterns: %{ "torrentDescNameValuePattern": "tr",
                      "torrentDescNamePattern": "td.td_newborder[align=right]",
                      "torrentDescValuePattern": "td.td_newborder+td.td_newborder",
                      "imgSelector": "#description img",
                      "imgAttrPattern": "src",
                      "imgLinkPattern": "previewimg.php",
                      "imgHiddenSelector": "td.td_clear div, td.td_clear a img",
                      "imgHiddenAttr": "style",
                      "imgHiddenPattern": "background-image: url\\('(?<url>.*)'\\);",
                      "imgFilterPattern": ".*(fullr.png|halfr.png|blankr.png|spacer.gif|arrow_hover.png).*",
                      "videoSelector": "#youtube_video",
                      "videoAttrPattern": "code"}
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