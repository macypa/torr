defmodule Torr.ImageDownloader do
  require Logger

  def download(torrents) do
    torrents |> Enum.each(fn torrent ->
                   unless is_nil(torrent.json["images"]) or torrent.json["images"] == [] do
                     for img <- torrent.json["images"] do
                       image = img |> String.trim |> String.replace("http://", "") |> String.replace("http://", "")
                       downloadImage(image)
                     end
                   end
                 end)
  end

  def downloadImage(url) do
      options = [hackney: [{:follow_redirect, true}], timeout: :infinity, recv_timeout: :infinity]
      body = case HTTPoison.get(url, [], options) do
          {:ok, %HTTPoison.Response{body: body, headers: _headers, status_code: 200}} ->
             body
          other -> Logger.info "img error: #{inspect(other)}"
      end

      url = url |> String.replace("http://", "") |> String.replace("http://", "")
      imgPath = "web/static/assets/images/#{url}"

      unless File.exists?(imgPath) do
        File.mkdir_p(imgPath)
        File.rmdir(imgPath)
        File.write(imgPath, body)
      end
  end
end
