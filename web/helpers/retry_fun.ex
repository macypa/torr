defmodule Torr.RetryFun do

  def retry(times, fun, delay \\ 1000, default \\ "") do
    res = Enum.reduce(1..times,
             fn(_, acc) ->
               acc = case acc do
                 1 -> ""
                 acc -> acc
               end
               case acc do
                 "" -> "#{acc}#{exec(fun, delay)}"
                 acc -> acc
               end
             end)

    case res do
      "" -> exec(fun, delay, default)
      res -> res
    end
  end

  def exec(fun, delay \\ 1000, default \\ "") do
    try do
      fun.()
    rescue
      _ -> :timer.sleep(delay);
           default
    end
  end
end