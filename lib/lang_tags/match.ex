defmodule LangTags.Match do
  @moduledoc """
  Matching of language tags against language ranges, according to
  [RFC 4647](https://tools.ietf.org/html/rfc4647).

  A *language range* identifies a set of language tags. The most common source
  of one is an HTTP `Accept-Language` header, where a client lists the ranges
  it will accept in order of preference; the server then picks from the tags it
  actually has.

  Two schemes are provided:

    * `filter/2` returns every tag a range covers, which suits listing all the
      acceptable options.
    * `lookup/2` returns the single best tag, which suits choosing one thing to
      serve.

  Both compare case-insensitively and return tags in the casing they were given
  in. Neither consults the registry, so a tag is matched as written, whether or
  not it is registered; pass it to `LangTags.check/1` first if that matters.
  """

  @doc """
  Returns every tag matched by any of the `ranges`, using basic filtering.

  A range matches a tag when it equals the tag, or when it equals a prefix of
  the tag and the next character in the tag is `-`. So `"de-DE"` matches
  `"de-DE-1996"` but not `"de-Deva"`. The range `"*"` matches every tag.

  Tags come back in the order they were given, each at most once, however many
  ranges match them.

  For more information, see [RFC 4647 section 3.3.1](https://tools.ietf.org/html/rfc4647#section-3.3.1).

  ## Examples

      iex> LangTags.Match.filter(["de-DE-1996", "de-Deva", "en-GB"], ["de-de"])
      ["de-DE-1996"]
      iex> LangTags.Match.filter(["de", "en-GB"], ["*"])
      ["de", "en-GB"]
      iex> LangTags.Match.filter(["fr"], ["de"])
      []

  """
  @spec filter([String.t()], String.t() | [String.t()]) :: [String.t()]
  def filter(tags, range) when is_binary(range), do: filter(tags, [range])

  def filter(tags, ranges) when is_list(ranges) do
    ranges = Enum.map(ranges, &String.downcase/1)

    Enum.filter(tags, fn tag ->
      downcased = String.downcase(tag)
      Enum.any?(ranges, &basic_match?(downcased, &1))
    end)
  end

  defp basic_match?(_tag, "*"), do: true
  defp basic_match?(tag, range), do: tag == range or String.starts_with?(tag, range <> "-")

  @doc """
  Returns the single tag that best matches `ranges`, or `nil` if none does.

  Ranges are tried in order, and the first one to produce a match wins, so the
  caller's priority beats the order of `tags`. A range that matches nothing is
  shortened one subtag at a time and tried again, which is how `"en-US"` falls
  back to `"en"`.

  Unlike `filter/2`, a range is only ever shortened, never extended: the range
  `"en"` does not match the tag `"en-GB"`.

  `nil` stands for the RFC's notion of a default value, which it leaves to each
  application to define. Supply your own with `lookup(tags, ranges) || "en"`.

  For more information, see [RFC 4647 section 3.4](https://tools.ietf.org/html/rfc4647#section-3.4).

  ## Examples

      iex> LangTags.Match.lookup(["zh-Hant", "en"], ["zh-Hant-CN"])
      "zh-Hant"
      iex> LangTags.Match.lookup(["fr", "en"], ["de", "en"])
      "en"
      iex> LangTags.Match.lookup(["en-GB"], ["en"])
      nil

  """
  @spec lookup([String.t()], String.t() | [String.t()]) :: String.t() | nil
  def lookup(tags, range) when is_binary(range), do: lookup(tags, [range])

  def lookup(tags, ranges) when is_list(ranges) do
    # Keyed by the lowercased tag so that shortening a range stays a map
    # lookup. The first spelling of a tag wins if one is listed twice.
    by_code = Enum.reduce(tags, %{}, &Map.put_new(&2, String.downcase(&1), &1))

    Enum.find_value(ranges, fn range -> match_range(by_code, String.downcase(range)) end)
  end

  # "*" says only that anything is acceptable, which is not enough to choose a
  # tag. It falls through to the next range, and to the default if it is last.
  defp match_range(_by_code, "*"), do: nil

  defp match_range(by_code, range) do
    case Map.fetch(by_code, range) do
      {:ok, tag} -> tag
      :error -> range |> truncate() |> match_shorter(by_code)
    end
  end

  defp match_shorter(nil, _by_code), do: nil
  defp match_shorter(range, by_code), do: match_range(by_code, range)

  defp truncate(range) do
    case range |> String.split("-") |> Enum.drop(-1) |> drop_trailing_singleton() do
      [] -> nil
      parts -> Enum.join(parts, "-")
    end
  end

  # A single-character subtag introduces the subtags after it — "x" for private
  # use, the others for extensions — so it means nothing once they are gone and
  # is dropped along with them rather than being tried on its own.
  defp drop_trailing_singleton([]), do: []

  defp drop_trailing_singleton(parts) do
    if parts |> List.last() |> String.length() == 1 do
      Enum.drop(parts, -1)
    else
      parts
    end
  end
end
