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
    trackers = trackers()

    for tracker <- trackers do
#    tracker = Repo.get(Tracker, 4)
      collectTorrentUrls(tracker)
    end

    Process.send_after(Torr.Parser, :work, 1)
    Logger.info "Crawler done"
  end

  def collectTorrentUrls(tracker) do
    Logger.debug "collectTorrentUrls tracker id: #{inspect(tracker.id)}"
    try do
      for _ <- Stream.cycle([:ok]) do
        tracker = Tracker |> Repo.get(tracker.id)
          Enum.each(0..tracker.pagesAtOnce, &(collectTorrentUrlsFromPage(tracker, tracker.lastPageNumber+&1)))

          if tracker.lastPageNumber+tracker.pagesAtOnce < 0 do
            #require IEx; IEx.pry
            raise "no more pages to search for torrents"
          end

          collectTorrents(tracker)
          Tracker.save(%{url: tracker.url, lastPageNumber: tracker.lastPageNumber+tracker.pagesAtOnce })
      end
    rescue
      e -> Logger.info "no more pages to download #{inspect(tracker.id)} : #{inspect(e)}"
            collectTorrents(tracker)
    end
  end

  def collectTorrentUrlsFromPage(tracker, pageNumber) do
    Logger.debug "collectTorrentUrlsFromPage: #{inspect(pageNumber)}"
    pageUrl = "#{tracker.url}#{tracker.pagePattern}#{pageNumber}"
    Logger.info "collectTorrentUrlsFromPage from: #{pageUrl}"

    pageHtml = Torr.Crawler.download(tracker, pageUrl)

    case runPattern(pageHtml, tracker.patterns["pageContainsTorrentsPattern"]) do
      "" -> #require IEx; IEx.pry
            raise "no more pages to search for torrents"
      _ ->  saveTorrentUrlsFromPage(tracker, pageNumber, pageHtml)
    end

    case runPattern(pageHtml, tracker.patterns["lastPagePattern"]) do
      "" -> saveTorrentUrlsFromPage(tracker, pageNumber, pageHtml)
      _ -> #require IEx; IEx.pry
            raise "no more pages to search for torrents"
    end
  end

  def saveTorrentUrlsFromPage(tracker, pageNumber, pageHtml) do

    urlReg = case Regex.compile(tracker.urlPattern, "u") do
      {:ok, urlRexgex} -> urlRexgex
      {:error, error} -> {:error, error}
    end

    banans = pageHtml |> Floki.find("a")
                      |> Floki.attribute("href")
                      |> Enum.filter(fn(torrUrl) -> String.match?(torrUrl, urlReg) end)
                      |> Enum.map(fn(torrUrl) -> Regex.named_captures(urlReg, torrUrl)["url"] end)
                      |> Enum.uniq
          #if tracker.name == "zelka.org" do
          #        require IEx; IEx.pry
          #      end
              Logger.debug "collectTorrentUrlsFromPage banans: #{banans}"
              case banans do
                [] -> #require IEx; IEx.pry
                      raise "no new torrents in page #{pageNumber}"
                banans -> banans
                                |> Enum.map(fn(torrUrl) ->
                                      Torr.Tracker.saveTorrent(tracker, %{tracker_id: tracker.id, page: pageNumber, torrent_id: torrUrl})
                                   end)
              end
  end

  def collectTorrents(tracker) do
    Logger.debug "collectTorrents tracker id: #{inspect(tracker.id)}"
    Torr.Tracker.allWithEmptyName(tracker)
                |> Repo.all
      #                  |> Enum.map(fn(torrUrl) -> Regex.named_captures(urlReg, torrUrl)["url"] end)
                |> Enum.each(fn torrent ->
                                torrData = fetchTorrentData(tracker, torrent.torrent_id)
                                case torrData do
                                  nil -> Logger.error "torrent #{torrent.torrent_id} is missing: #{inspect(torrData)}"
                                         Torr.Tracker.deleteTorrent(tracker, %{torrent_id: torrent.torrent_id})
                                  change -> Torr.Tracker.saveTorrent(tracker, change)
                                end
                              end)
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
    Logger.debug "fetchTorrentData tracker id: #{inspect(tracker.id)}  torrent_id: #{inspect(torrent_id)}"
    Logger.info "collectTorrent from: #{tracker.url}#{tracker.infoUrl}#{torrent_id}#{tracker.patterns["urlsuffix"]}"
    htmlString = download(tracker, "#{tracker.url}#{tracker.infoUrl}#{torrent_id}#{tracker.patterns["urlsuffix"]}")
    htmlString = case htmlString do
      "" -> #require IEx; IEx.pry
            altUrl = tracker.patterns["alternativeUrl"]
            case altUrl do
              nil -> ""
              "" -> ""
              altUrl -> download(tracker, "#{altUrl}#{tracker.infoUrl}#{torrent_id}#{tracker.patterns["urlsuffix"]}")
            end
      htmlString -> htmlString
    end
#    Logger.info "fetchTorrentData htmlString : #{htmlString}"

    name = htmlString |> runPattern(tracker.namePattern)
    case name do
      nil -> nil
      [] -> nil
      "" -> nil
      name -> case name |> Floki.text do
              "" -> nil
              name ->
                contentHtml = htmlString |> runPattern(tracker.htmlPattern)
                contentHtml = :iconv.convert("utf-8", "utf-8", contentHtml)

  #      if tracker.name == "arenabg.com" do
  #        require IEx; IEx.pry
  #      end
                contentHtml = case runPattern(contentHtml, tracker.patterns["categoryPattern"]) do
                  "" -> require IEx; IEx.pry
                        raise "no category/type found on page ...probably wrong page is downloaded"
                  _ -> contentHtml
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
  end

  def runPattern(content, pattern) do
    result = if String.starts_with?(pattern, "~r/") do
      regex = Regex.split(~r{~r/(?<reg>.*)/.*$}, pattern, on: [:reg], include_captures: true)
      reg = case Regex.compile(Enum.at(regex, 1), Enum.at(regex, 2) |> String.slice(1..-1)) do
        {:ok, regex} -> regex
        {:error, error} -> {:error, error}
      end

      names = Regex.names(reg)
      case names do
        [] -> case Regex.run(reg, content) do
                nil -> [""]
                res -> res
              end
        names -> case Regex.named_captures(reg, content)[names |> Enum.at(0)] do
                   nil -> [""]
                   res -> [res]
                 end
      end
    else
      content |> Floki.find(pattern)
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
    Torr.RetryFun.retry(3, fn ->
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
      end, delay)
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

      charset = Enum.reduce(headers, "", fn kv, acc ->
        {k, v} = kv
        acc <> case k do
                  "Content-Type" -> Regex.named_captures(~r/charset=(?<charset>.*?)(;|$)/us, v)["charset"]
                  nil -> ""
                  _ -> ""
                end
        end)
      toUtf8 = :iconv.convert(charset, "utf-8", decompressed)
      toUtf8 = String.replace(toUtf8, "\u0000", "")
      :iconv.convert("utf-8", "utf-8", toUtf8)
  end

  def trackers() do
      trackerMaps() |> Enum.each(fn x -> x |> Tracker.save end)
      Torr.Tracker.all
  end

  def trackerMaps() do
      [
      %{
        url: "http://zamunda.net/",
        name: "zamunda.net",
        pagesAtOnce: 2,
        delayOnFail: 1000,
        pagePattern: "bananas?sort=6&type=asc&page=",
        infoUrl: "banan?id=",
        urlPattern: "(|javascript)banan\\?id=(?<url>\\d+)",
#        htmlPattern: "h1",
        namePattern: "~r/<h1.*?<\/h1>/su",
#        htmlPattern: "h1 ~ table",
        htmlPattern: "~r/<h1.*?(Add|Show)\s*comment.*?<\/table>|<h1.*$/su",
        cookie: "PHPSESSID=b2en7vbfb02e2a6l86q2l4vsh0; cookieconsent_dismissed=yes; uid=4656705; pass=2e47932cbb4cf7a6bca4766fb98e4c5f; cats=7; periods=7; statuses=1; howmanys=1; a=22; __utmt=1; ismobile=no; swidth=1920; sheight=1055; russian_lang=no; g=m; __utma=100172053.259253342.1483774748.1483988651.1484001975.4; __utmb=100172053.2.10.1484001975; __utmc=100172053; __utmz=100172053.1483774748.1.1.utmcsr=(direct)|utmccn=(direct)|utmcmd=(none)",
        patterns: %{ "urlsuffix": "&filelist=1",
                     "lastPagePattern": "~r/Sorry, nothing found/su",
                     "pageContainsTorrentsPattern": "~r/id=\"submitsearch\".*?banan?id=/su",
                     "categoryPattern": "~r/<td[^>]*?>Type(?<type></.*?)</td>/su",
                     "genrePattern": "~r/<td[^>]*?>Genre(?<genre></.*?)</td>/su",
                     "genrePattern2": "~r/(Жанр|Genre)(?<genre>.*?)(<br|</td)/su",
                     "descriptionPattern": "#description",
                     "torrentDescNameValuePattern": "tr",
                     "torrentDescNamePattern": "td.td_newborder[align=right]",
                     "torrentDescValuePattern": "td.td_newborder[align=right]+td",
                     "imgSelector": "#description img",
                     "imgAttrPattern": "src",
                     "imgFromLinkReg": "~r/.*/su",
                     "imgFromLinkPrefix": "",
                     "imgLinkPattern": "previewimg.php",
                     "imgHiddenSelector": "td.td_clear div, td.td_clear a img",
                     "imgHiddenAttr": "style",
                     "imgHiddenPattern": "background-image: url\\('(?<url>.*)'\\);",
                     "imgFilterPattern": ".*(fullr.png|halfr.png|blankr.png|spacer.gif|arrow_hover.png).*",
                     "videoSelector": "#youtube_video",
                     "videoAttrPattern": "code"}
      },
      %{
        url: "http://zelka.org/",
        name: "zelka.org",
        pagesAtOnce: -2,
#        lastPageNumber: 199,
        delayOnFail: 1000,
        pagePattern: "browse.php?sort=6&type=desc&page=",
        infoUrl: "details.php?id=",
        urlPattern: "(^|javascript)details\\.php\\?id=(?<url>\\d+)",
        namePattern: "~r/<h1.*?<\/h1>/su",
        htmlPattern: "~r/<h1.*?(Add|Show)\s*comment.*?<\/table>|<h1.*$/su",
        cookie: "uid=3296682; pass=cf2c4af26d3d19b8ebab768f209152a5; accag=ccage",
        patterns: %{ "alternativeUrl": "http://pruc.org/",
                     "urlsuffix": "&filelist=1",
                     "lastPagePattern": "~r/Нищо не е намерено/su",
                     "pageContainsTorrentsPattern": "~r/id=\"submitsearch\".*?details.php?id=/su",
                     "categoryPattern": "~r/<td[^>]*?>Type(?<type></.*?)</td>/su",
                     "genrePattern": "~r/<td[^>]*?>Genre(?<genre></.*?)</td>/su",
                     "genrePattern2": "~r/(Жанр|Genre)(?<genre>.*?)(<br|</td)/su",
                     "descriptionPattern": "#description",
                     "torrentDescNameValuePattern": "tr",
                     "torrentDescNamePattern": "td.heading[align=right]",
                     "torrentDescValuePattern": "td.heading[align=right]+td",
                     "imgSelector": "#description img",
                     "imgAttrPattern": "src",
                     "imgFromLinkReg": "~r/.*/su",
                     "imgFromLinkPrefix": "",
                     "imgLinkPattern": "previewimg.php",
                     "imgHiddenSelector": "td.td_clear div, td.td_clear a img",
                     "imgHiddenAttr": "style",
                     "imgHiddenPattern": "background-image: url\\('(?<url>.*)'\\);",
                     "imgFilterPattern": ".*(fullr.png|halfr.png|blankr.png|spacer.gif|arrow_hover.png).*",
                     "videoSelector": "#youtube_video",
                     "videoAttrPattern": "code"}
      },
      %{
        url: "http://arenabg.com/",
        name: "arenabg.com",
        pagesAtOnce: 2,
        delayOnFail: 1000,
        pagePattern: "en/torrents/sort:date/dir:asc/page:",
        infoUrl: "en/torrent-download-",
        urlPattern: "en/torrent-download-(?<url>.*?)(#|$)",
        namePattern: "~r/<h3.*?<\/h3>/su",
        htmlPattern: "~r/<h2.*?You must login before post comments</div>|<h2.*$/su",
        cookie: "lang=en; __utma=232206415.1112305381.1480870454.1485560022.1485564408.6; __utmz=232206415.1480870454.1.1.utmcsr=(direct)|utmccn=(direct)|utmcmd=(none); __auc=7336a9dd158cac1e4fcaa7dd034; skin=black; SESSID=rjbdsl6trs2p7j9e6fsvc86nr6; __utmb=232206415.1.10.1485564408; __utmc=232206415; __utmt=1; __asc=506ca636159e289f08a443e6944",
        patterns: %{ "urlsuffix": "",
                     "lastPagePattern": "~r/There are no results found/su",
                     "pageContainsTorrentsPattern": "~r/id=\"search-button\".*?torrent-download/su",
                     "categoryPattern": "~r/<b>Category</b>:(?<type>.*?)</a>/su",
                     "genrePattern": "~r/<b>Category</b>.*?</a>.*?<a.*?>(?<genre>.*?)</a>/su",
                     "genrePattern2": "~r/(Жанр:|Genre:)(?<genre>.*?)(<br|</td)/su",
                     "descriptionPattern": "~r/Torrent:(?<desc>.*?)id=\"comments\"/su",
                     "torrentDescNameValuePattern": ".table-details tr",
                     "torrentDescNamePattern": "td.hidden-xs",
                     "torrentDescValuePattern": "td.hidden-xs+td",
                     "imgSelector": "img.lazy, a[rel='nofollow'] img",
                     "imgAttrPattern": "src",
                     "imgFromLinkReg": "~r/.*/su",
                     "imgFromLinkPrefix": "",
                     "imgLinkPattern": "previewimg.php",
                     "imgHiddenSelector": "td.td_clear div, td.td_clear a img",
                     "imgHiddenAttr": "style",
                     "imgHiddenPattern": "background-image: url\\('(?<url>.*)'\\);",
                     "imgFilterPattern": ".*(fullr.png|halfr.png|blankr.png|spacer.gif|arrow_hover.png|valid_css|valid_html).*",
                     "videoPattern": "~r/youtube.com/embed/(?<tubeid>.*?)\"/su"}
      },
      %{
        url: "http://alein.org/",
        name: "alein.org",
        pagesAtOnce: 2,
        delayOnFail: 1000,
        pagePattern: "index.php?page=torrents&active=1&order=3&by=1&pages=",
        infoUrl: "index.php?page=torrent-details&id=",
        urlPattern: "page=torrent-details&id=(?<url>.*?)(#|$)",
        namePattern: "~r/>Name</td>(?<name>.*?)</td>/su",
        htmlPattern: "~r/>Name</td>.*?history.go|>Name</td>.*$/su",
        cookie: "_ga=GA1.2.1213498673.1485510803; _popfired=1; xbtit=lnlkrkmtt3qjms086pdtdqn1d6",
        patterns: %{ "urlsuffix": "#expand",
                     "lastPagePattern": "~r/class=\"pagercurrent\"><b>\\d+</b></span>\\s*</form>/su",
                     "pageContainsTorrentsPattern": "~r/Name</a>.*?page=torrent-details/su",
                     "categoryPattern": "~r/<td[^>]*?>Category(?<type></.*?)</td>/su",
                     "genrePattern": "~r/<td[^>]*?>Genre(?<genre></.*?)</td>/su",
                     "genrePattern2": "~r/(Жанр:|Genre:)(?<genre>.*?)(<br|</td)/su",
                     "descriptionPattern": "~r/<td[^>]*?>Description(?<genre>.*?)Screenshots/su",
                     "torrentDescNameValuePattern": ".table-details tr",
                     "torrentDescNamePattern": "td.header",
                     "torrentDescValuePattern": "td.header+td",
                     "imgSelector": "a[title='view image'] img",
                     "imgAttrPattern": "src",
                     "imgFromLinkReg": "~r/image=(?<img>.*)/su",
                     "imgFromLinkPrefix": "torrentimg/",
                     "imgLinkPattern": "previewimg.php",
                     "imgHiddenSelector": "td.td_clear div, td.td_clear a img",
                     "imgHiddenAttr": "style",
                     "imgHiddenPattern": "background-image: url\\('(?<url>.*)'\\);",
                     "imgFilterPattern": ".*(fullr.png|halfr.png|blankr.png|spacer.gif|arrow_hover.png).*",
                     "videoPattern": "~r/youtube.com/embed/(?<tubeid>.*?)\"/su"}
      }
# http://energy-torrent.com/browse.php
# http://www.novaset.net/index.php?page=torrents
# http://p2pbg.com/index.php?page=torrents
      ]
  end
end