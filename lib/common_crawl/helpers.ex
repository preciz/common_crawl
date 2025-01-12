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
        if backoff_ms > 0, do: Process.sleep(backoff_ms)
        do_with_attempts(fun, max_attempts, attempt + 1, backoff_ms)

      {:halt, error} ->
        error
    end
  end
end
