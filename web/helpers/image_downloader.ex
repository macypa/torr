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
    url = url |> String.replace("http://", "") |> String.replace("http://", "") |> URI.decode() |> URI.encode

    headers = [
                "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Ubuntu Chromium/53.0.2785.143 Chrome/53.0.2785.143 Safari/537.36",
                "Referer": url,
              ]
    options = [connect_timeout: 1000000, timeout: 1000000, recv_timeout: 1000000, hackney: [{:follow_redirect, true}]]
    case HTTPoison.get(url, headers, options) do
             {:ok, %HTTPoison.Response{body: body, headers: _headers, status_code: 200}} ->
                body
             other -> Logger.info "img #{url} error: #{inspect(other)}"
                      case File.read(Path.wildcard("web/static/assets/images/404/*") |> Enum.random) do
                        {:ok, body}      -> body
                        {:error, reason} -> reason
                      end
           end
  end
end
