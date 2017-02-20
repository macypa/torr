defmodule Torr.Parser do
  require Logger
  use GenServer
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
    trackers = Torr.Crawler.trackers()

    for tracker <- trackers do
#    tracker = Torr.Repo.get(Torr.Tracker, 7)
      processTorrents(tracker)
    end

#    processEmptyTypeGenre()

#    Torr.Torrent.save(Torr.Parser.processTorrentData(Torr.Repo.get(Torr.Tracker, 8), 10783))

    Logger.warn "Parser done"
  end

  def processTorrents(tracker) do
    Logger.info "processTorrents: #{inspect(tracker)}"
    try do
        for _ <- Stream.cycle([:ok]) do
          notProcessed = Torr.Tracker.notProcessed(tracker)
#                                  |> Repo.preload([:tracker])
                          |> Repo.all

          case notProcessed do
                [] -> #require IEx; IEx.pry
                      raise "no new torrents to process"
                notProcessed -> notProcessed |> Enum.each(fn torrentDBId ->

                                                    try do
                                                       data = processTorrentData(tracker, torrentDBId)
                                                       Torr.Torrent.save(data)
                                                    rescue
                                                      e -> Logger.warn "processTorrentData warn: #{inspect(e)}"
                                                            :ok
                                                    end

                                                end)
          end
        end
      rescue
        e -> Logger.warn "processTorrents warn #{inspect(tracker.url)} : #{inspect(e)}"
              :ok
      end

  end

  def processEmptyTypeGenre() do
    Logger.info "processTorrentsTypeGenre..."
    try do
        for _ <- Stream.cycle([:ok]) do
          notProcessed = Torr.Torrent
                          |> Torr.Torrent.allWithEmptyType()
                          |> Repo.all

          case notProcessed do
                [] -> #require IEx; IEx.pry
                      raise "no torrents with empty type"
                notProcessed -> notProcessed |> Enum.each(fn torrent ->

                                                    try do
                                                       tracker = Repo.get(Torr.Tracker, torrent.tracker_id)
                                                       data = processTorrentTypeGenre(tracker, torrent)
                                                       Torr.Torrent.save(data)
                                                    rescue
                                                      e -> Logger.warn "processTorrentTypeGenre warn: #{inspect(e)}"
                                                            :ok
                                                    end

                                                end)
          end
        end
      rescue
        e -> Logger.warn "processTorrentTypeGenre warn: #{inspect(e)}"
              :ok
      end

  end

  def processTorrentTypeGenre(tracker, torrent) do
    torrent = Torr.Tracker.get_torrent_by_torrent_id(tracker, torrent)

    Logger.info "processTorrentTypeGenre : torrent id:#{inspect(torrent.id)}"

    uniq_name = getUniqName(torrent.name)
    category = getType(torrent, tracker)
    genre = getGenre(torrent, tracker)

    %{
      uniq_name: uniq_name,
      type: category,
      genre: genre,
      tracker_id: torrent.tracker_id,
      torrent_id: torrent.torrent_id,
    }

  end

  def getUniqName(name) do
    name |> String.downcase
                      |> String.replace(~r/\[[^\[\]]*?\]/us, "")
                      |> String.replace(~r/\s*((с|е|e|s)\d+).*/us, "")
                      |> String.replace(~r/\s*(season|сезон).*/us, "")
                      |> String.replace(~r/\s*(\s\w{2,3}rip\s|\sxvid\s|\shdtv\s|\sx264\s|\sdvd\s).*/us, "")
                      |> String.replace(~r/[^\\(\\)0-9 A-Z a-z а-я А-Я]/us, "")
                      |> String.split(" / ") |> Enum.at(0)
                      |> String.trim
  end

  def getType(torrent, tracker) do
    Torr.Crawler.runPattern(torrent.content_html, tracker.patterns["categoryPattern"])
                    |> Floki.text
                    |> String.trim
                    |> Torr.FilterData.convertType
  end

  def getAddedDate(torrent, tracker) do
    Torr.Crawler.runPattern(torrent.content_html, tracker.patterns["datePattern"])
                    |> Floki.text
                    |> String.trim
  end

  def getSize(torrent, tracker) do
    Torr.Crawler.runPattern(torrent.content_html, tracker.patterns["sizePattern"])
                    |> Floki.text
                    |> String.trim
  end

  def getGenre(torrent, tracker) do
    Torr.Crawler.runPattern(torrent.content_html, tracker.patterns["genrePattern"]) <> ", " <> Torr.Crawler.runPattern(torrent.content_html, tracker.patterns["genrePattern2"])
                   |> Floki.text
                   |> String.replace(":", "")
                   |> String.replace(~r/\//su, ",")
                   |> String.replace(~r/\|/su, ",")
                   |> String.replace(~r/\./us, "")
                   |> String.replace(~r/,\s*,/su, "")
                   |> String.replace(~r/\d+/su, "")
                   |> String.replace(~r/[\w]+:.*/su, "")
                   |> String.replace(~r/\*.*/su, "")
                   |> String.replace(~r/•.*/su, "")
                   |> String.replace(~r/[^>]+>.*/su, "")
                   |> String.replace(":ArenaBG.TV", "")
                   |> Floki.text
                   |> String.trim
                   |> String.split(",")
                   |> Enum.filter(fn(genr) -> String.length(genr) > 2 end)
                   |> Enum.map(fn(genr) -> String.trim(genr) end)
                   |> Enum.uniq
                   |> Enum.sort
                   |> Enum.join(", ")
                   |> String.replace(~r/^, /us, "")
                   |> String.replace(~r/, $/us, "")
                   |> String.replace(~r/\./us, "")
                   |> String.replace(~r/^\s*-+\s*/us, "")
                   |> String.replace(~r/^\s*#+\s*/us, "")
                   |> String.replace(~r/^\s*-\s*/us, "")
                   |> String.replace(~r/\s*-\s*;/us, ",")
                   |> String.slice(0, 55)
                   |> String.replace(~r/,\s*\w+$/us, "")
                   |> String.trim
  end

  def processTorrentData(tracker, torrentDBId) do

    torrent = Torr.Tracker.getQuery(tracker) |> Torr.Repo.get(torrentDBId)

    Logger.info "processTorrentData tracker : #{inspect(tracker.url)} torrent id:#{inspect(torrent.id)}"

    uniq_name = getUniqName(torrent.name)
    category = getType(torrent, tracker)
    genre = getGenre(torrent, tracker)

    %{
      name: torrent.name,
      uniq_name: uniq_name,
      type: category,
      genre: genre,
      tracker_id: tracker.id,
      torrent_id: torrent.torrent_id,
      json: updateJson(torrent, tracker)
    }

  end

  def updateJson(torrent, tracker) do
    Logger.debug "updateJson"
    contentHtml = torrent.content_html
    torrentInfo = %{}

    contentHtml = contentHtml |> String.replace(">>>", "") |> String.replace("<<<", "")
                              |> String.replace("?>", "") |> String.replace("<?", "")

    torrentInfo = contentHtml |> Floki.find(tracker.patterns["torrentDescNameValuePattern"])
                              |> Enum.reduce(torrentInfo, fn x, acc ->
                                    Map.put(acc,
                                            Floki.find(x, tracker.patterns["torrentDescNamePattern"]) |> Floki.text |> String.replace(~r/\n|\r/, "") |> String.trim,
                                            Floki.find(x, tracker.patterns["torrentDescValuePattern"]) |> Floki.text |> String.trim)
                                  end)

    description = Torr.Crawler.runPattern(contentHtml, tracker.patterns["descriptionPattern"]) |> Floki.text
    torrentInfo = case description do
      "" -> torrentInfo
      descr -> torrentInfo |> Map.put( "Description", descr |> String.trim)
    end

    added = getAddedDate(torrent, tracker)
    torrentInfo = case added do
      "" -> torrentInfo
      added -> torrentInfo |> Map.put( "Added", added |> String.trim)
    end

    size = getSize(torrent, tracker)
    torrentInfo = case size do
      "" -> torrentInfo
      size -> torrentInfo |> Map.put( "Size", size |> String.trim)
    end

    images = getImages(contentHtml, tracker)
    torrentInfo = if torrentInfo["Type"] != nil and String.contains?(torrentInfo["Type"], "XXX") do
      torrentInfo |> Map.put("imagesHidden", images)
                  |> Map.put("imagesHidden", getHiddenImages(contentHtml, tracker))
    else
      Map.put(torrentInfo, "images", images)
    end

    torrentInfo = Map.put(torrentInfo, "video", getVideos(contentHtml, tracker))

    torrentInfo
  end

  def getImages(contentHtml, tracker) do
    Logger.debug "getImages"

    imgReg = case Regex.compile(tracker.patterns["imgFilterPattern"], "u") do
      {:ok, imgRexgex} -> imgRexgex
      {:error, error} -> {:error, error}
    end

    images = contentHtml |> Floki.find(tracker.patterns["imgSelector"])
                          |> Floki.attribute(tracker.patterns["imgAttrPattern"])
                          |> Enum.map(fn(imgUrl) ->
                                          url = Torr.Crawler.runPattern(imgUrl, tracker.patterns["imgFromLinkReg"])
                                          case url do
                                            nil -> imgUrl
                                            "" -> imgUrl
                                            url -> tracker.patterns["imgFromLinkPrefix"] <> url
                                          end
                                      end)
                          |> Enum.filter(fn(imgUrl) -> not String.match?(imgUrl, imgReg) end)
                          |> Enum.uniq

      Logger.debug "getImages images: #{images}"
#
    images |> Enum.map(fn(imgUrl) -> unless String.starts_with?(imgUrl, "http") do tracker.url <> imgUrl else imgUrl end end)
           |> Enum.map(fn(imgUrl) -> imgUrl |> String.replace("https://", "") |> String.replace("http://", "") end)


  end

  def getHiddenImages(contentHtml, tracker) do
    Logger.debug "getHiddenImages"

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
      linksContent = Torr.Crawler.download(tracker, imagePreviewLink)
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
            |> Enum.map(fn(imgUrl) -> unless String.starts_with?(imgUrl, "http") do tracker.url <> imgUrl else imgUrl end end)
            |> Enum.map(fn(imgUrl) -> imgUrl |> String.replace("https://", "") |> String.replace("http://", "") end)
    end
  end

  def getVideos(contentHtml, tracker) do
    Logger.debug "getVideos"

    videoReg = tracker.patterns["videoPattern"]
    case videoReg do
      nil -> contentHtml |> Floki.find(tracker.patterns["videoSelector"])
                              |> Floki.attribute(tracker.patterns["videoAttrPattern"])
      videoReg -> contentHtml |> Torr.Crawler.runPattern(videoReg)
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

end