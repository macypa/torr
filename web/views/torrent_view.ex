defmodule Torr.TorrentView do
  use Torr.Web, :view
  import Scrivener.HTML

  def decodeOneImage(params, torrent) do
    case getImages(params, torrent) do
      nil -> decodeImg(nil)
      images -> case List.first(images) do
                  nil -> decodeImg(nil)
                  img -> unless String.match?(img, ~r/\.[a-zA-Z]+$/us) do
                          decodeImg(List.last(images))
                        else
                          decodeImg(img)
                        end
                end
    end
  end

  def decodeImgFirst(imges) do
    case imges do
      nil -> ""
      img -> decodeImg(img |> Enum.at(0))
    end
  end

  def decodeImg(img) do
    case img do
      nil -> "notFound"
      img -> decode(img |> String.trim |> String.replace("http://", "") |> String.replace("http://", ""))

    end
  end

  def getImages(params, torrent) do
    if is_nil(params["showAll"]) do
      if torrent.json["Type"] != nil and String.contains?(torrent.json["Type"], "XXX") do
        nil
      else
        torrent.json["images"]
      end
    else
      unless is_nil(torrent.json["imagesHidden"]) do
        images = Enum.concat(unless is_nil(torrent.json["images"]) do
                      torrent.json["images"] else [] end,
                      torrent.json["imagesHidden"] |> Enum.filter(fn(imgUrl) -> not String.match?(imgUrl, ~r/\.php/us) end)
                    )

      else
        torrent.json["images"]
      end
    end
  end

  defp decode(url) do
    try do
      url |> URI.decode()
    rescue
      _ -> "notValid"
    end
  end
end
