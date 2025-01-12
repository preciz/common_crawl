defmodule CommonCrawl.HelpersTest do
  use ExUnit.Case, async: true
  import CommonCrawl.Helpers

  test "attempts function N times before giving up" do
    uid = :crypto.strong_rand_bytes(8)

    put(uid, 0)

    result =
      with_attempts(
        fn ->
          val = get(uid)

          put(uid, val + 1)

          {:error, :noise}
        end,
        3
      )

    assert get(uid) == 3
    assert result == {:error, :noise}
  end

  test "attempts function only once if successful" do
    uid = :crypto.strong_rand_bytes(8)

    put(uid, 0)

    result =
      with_attempts(
        fn ->
          val = get(uid)

          put(uid, val + 1)

          {:ok, :noise}
        end,
        3
      )

    assert get(uid) == 1
    assert result == {:ok, :noise}
  end

  defp put(key, val), do: :persistent_term.put(key, val)
  defp get(key), do: :persistent_term.get(key)
end
