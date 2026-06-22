defmodule CommonCrawl.Helpers do
  @doc """
  Attempt an anonymous function `max_attempts` times.
  The function must return an `{:ok, _}`, `{:error, _}` or `{:halt, _}` tuple.
  """
  def with_attempts(fun, max_attempts, backoff_ms \\ 0)
      when is_function(fun, 0) and is_integer(backoff_ms) do
    do_with_attempts(fun, max_attempts, 1, backoff_ms)
  end

  defp do_with_attempts(fun, last_attempt, last_attempt, _backoff_ms), do: fun.()

  defp do_with_attempts(fun, max_attempts, attempt, backoff_ms) when attempt < max_attempts do
    case fun.() do
      {:ok, result} ->
        {:ok, result}

      {:error, _} ->
        if backoff_ms > 0 do
          max_backoff = 30_000
          # Calculate exponential backoff limit: base_backoff * 2^(attempt - 1)
          factor = :math.pow(2, attempt - 1) |> round()
          temp_limit = backoff_ms * factor
          sleep_limit = max(1, min(max_backoff, temp_limit))
          # Full jitter: random sleep between 1 and sleep_limit
          sleep_time = :rand.uniform(sleep_limit)
          Process.sleep(sleep_time)
        end
        do_with_attempts(fun, max_attempts, attempt + 1, backoff_ms)

      {:halt, error} ->
        error
    end
  end
end
