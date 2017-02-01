defmodule Torr.TorrentView do
  use Torr.Web, :view
  import Scrivener.HTML

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

  defp decode(url) do
    try do
      url |> URI.decode()
    rescue
      _ -> "notValid"
    end
  end
end
