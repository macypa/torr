defmodule Torr.ImageDownloader do
  require Logger

  def download(torrents) do
    torrents |> Enum.each(fn torrent ->
                   downloadList(torrent.json["images"])
                   downloadList(torrent.json["imagesHidden"])
                 end)
  end

  def downloadList(images) do
    unless is_nil(images) or images == [] do
      for img <- images do
        image = img |> String.trim |> String.replace("http://", "") |> String.replace("http://", "")
        downloadImage(image)
      end
    end
  end

  def downloadImage(url) do
    url = url |> String.replace("http://", "") |> String.replace("http://", "") |> URI.decode()

    unless File.exists?(url) do
      headers = [
                      "Accept-Encoding": "gzip;deflate,sdch",
                      "Accept-Language": "en-US,en;q=0.8",
                      "Upgrade-Insecure-Requests": "1",
                      "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Ubuntu Chromium/53.0.2785.143 Chrome/53.0.2785.143 Safari/537.36",
                      "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
                      "Referer": "http://zamunda.net/bananas",
      #                "Cookie": tracker.cookie,
                      "Connection": "keep-alive"
                    ]
      options = [connect_timeout: 1000000, timeout: 1000000, recv_timeout: 1000000, hackney: [{:follow_redirect, true}]]
      case HTTPoison.get(url, headers, options) do
               {:ok, %HTTPoison.Response{body: body, headers: _headers, status_code: 200}} ->
                  body
               other -> Logger.info "img #{url} error: #{inspect(other)}"
                  case File.read("web/static/assets/images/404/#{:rand.uniform(2)}.jpg") do
                    {:ok, body}      -> body
                    {:error, reason} -> reason
                  end
             end

#      imgPath = "web/static/assets/images/remote/#{url}"
#      unless File.exists?(imgPath) do
#        File.mkdir_p(imgPath)
#        File.rmdir(imgPath)
#        File.write(imgPath, body)
#      end
    end
  end
end
