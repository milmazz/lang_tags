defmodule LangTags.Tag do
  @moduledoc """
  Tags registered according to the rules in [RFC3066](https://tools.ietf.org/html/rfc3066)

  Please note that this *tags*  appears in records whose *type* is either 'grandfathered'
   or 'redundant' and contains a tag registered under [RFC3066](https://tools.ietf.org/html/rfc3066).

   For more information, see [section 2.2.8](https://tools.ietf.org/html/bcp47#section-2.2.8)
  """

  alias LangTags.Registry
  alias LangTags.SubTag

  @typedoc """
  A single validation failure.

  `:code` identifies the rule that was broken, `:subtag` is the offending
  code (or the whole tag, for `:deprecated`), and `:message` is a
  human-readable description.
  """
  @type error :: %{code: atom, subtag: String.t(), message: String.t()}

  # Canonical subtag order from the RFC 5646 ABNF:
  # language-extlang-script-region-variant
  @ranks %{"language" => 0, "extlang" => 1, "script" => 2, "region" => 3, "variant" => 4}

  @singular_types [
    {"language", :extra_language},
    {"extlang", :extra_extlang},
    {"script", :extra_script},
    {"region", :extra_region}
  ]

  @doc """
  Creates a new tag as a map

  ## Examples

      iex> LangTags.Tag.new("en-gb-oed")
      %{"Record" => %{"Added" => "2003-07-09", "Deprecated" => "2015-04-17",
          "Description" => ["English, Oxford English Dictionary spelling"],
          "Preferred-Value" => "en-GB-oxendict", "Tag" => "en-gb-oed",
          "Type" => "grandfathered"}, "Tag" => "en-gb-oed"}

  """
  @spec new(String.t()) :: map
  def new(tag) do
    # Lowercase for consistency (case is only a formatting
    # convention, not a standard requirement)
    tag = tag |> String.trim() |> String.downcase()

    # Most tags are neither grandfathered nor redundant, so a miss here is the
    # common case and must not go through an exception.
    case Registry.fetch_tag(tag) do
      {:ok, record} -> %{"Tag" => tag, "Record" => record}
      :error -> %{"Tag" => tag}
    end
  end

  @doc """
  If the tag is listed as *deprecated* or *redundant* it might have a preferred value. This method returns a tag as a map if so.

  ## Examples

      iex> LangTags.Tag.preferred("i-klingon")
      %{"Tag" => "tlh"}
      iex> "zh-cmn-Hant" |> LangTags.Tag.new() |> LangTags.Tag.preferred()
      %{"Tag" => "cmn-hant"}

  """
  @spec preferred(map | String.t()) :: map | nil
  def preferred(tag) when is_binary(tag), do: tag |> new() |> preferred()

  def preferred(tag) when is_map(tag) do
    preferred = tag["Record"]["Preferred-Value"]

    if preferred, do: new(preferred)
  end

  @doc """
  Returns a list of subtags making up the tag, as `Subtag` maps.

  Note that if the tag is *grandfathered* the result will be an empty list

  ## Examples

      iex> LangTags.Tag.subtags("en-gb-oed")
      []
      iex> LangTags.Tag.subtags("az-arab")
      LangTags.Tag.subtags("az-arab")

  """
  @spec subtags(map | String.t()) :: [map] | []
  def subtags(tag) when is_map(tag), do: process_subtags(tag, tag["Record"]["Type"])
  def subtags(tag) when is_binary(tag), do: tag |> new() |> subtags()

  @doc """
  Shortcut for `find/2` with a `language` filter

  ## Examples

      iex> LangTags.Tag.language("az-arab")
      %{"Record" => %{"Added" => "2005-10-16", "Description" => ["Azerbaijani"],
        "Scope" => "macrolanguage", "Subtag" => "az", "Type" => "language"},
        "Subtag" => "az"}

  """
  @spec language(map | String.t()) :: map
  def language(tag) when is_map(tag), do: find(tag, "language")
  def language(tag) when is_binary(tag), do: tag |> new() |> language()

  @doc """
  Shortcut for `find/2` with a `region` filter

  ## Examples

      iex> LangTags.Tag.region("en-gb-oeb")["Record"]["Description"] == ["United Kingdom"]
      true

  """
  @spec region(map | String.t()) :: map
  def region(tag) when is_map(tag), do: find(tag, "region")
  def region(tag) when is_binary(tag), do: tag |> new() |> region()

  @doc """
  Shortcut for `find/2` with a `script` filter

  ## Examples

      iex> LangTags.Tag.script("az-arab")
      %{"Record" => %{"Added" => "2005-10-16", "Description" => ["Arabic"],
        "Subtag" => "arab", "Type" => "script"}, "Subtag" => "arab"}

  """
  @spec script(map | String.t()) :: map
  def script(tag) when is_map(tag), do: find(tag, "script")
  def script(tag) when is_binary(tag), do: tag |> new() |> script()

  @doc """
  Find a subtag of the given type from those making up the tag.

  ## Examples

      iex> LangTags.Tag.find("az-arab", "script")
      %{"Record" => %{"Added" => "2005-10-16", "Description" => ["Arabic"],
        "Subtag" => "arab", "Type" => "script"}, "Subtag" => "arab"}

  """
  @spec find(map | String.t(), String.t()) :: map
  def find(tag, filter) when is_map(tag), do: Enum.find(subtags(tag), &(type(&1) == filter))
  def find(tag, filter) when is_binary(tag), do: tag |> new() |> find(filter)

  @doc """
  Returns `true` if the tag is valid, `false` otherwise.

  A tag is valid when every subtag is registered, appears in the order
  required by [RFC 5646 section 2.2.9](https://tools.ietf.org/html/rfc5646#section-2.2.9),
  and is not deprecated. See `errors/1` for why a tag was rejected.

  ## Examples

      iex> LangTags.Tag.valid?("en-GB")
      true
      iex> LangTags.Tag.valid?("en-en")
      false
      iex> LangTags.Tag.valid?("wubble")
      false

  """
  @spec valid?(map | String.t()) :: boolean
  def valid?(tag) when is_map(tag), do: errors(tag) == []
  def valid?(tag) when is_binary(tag), do: tag |> new() |> valid?()

  @doc """
  Returns every reason the tag is invalid, or an empty list if it is valid.

  Each entry is a map with a `:code`, the offending `:subtag`, and a
  human-readable `:message`. All problems are reported, not just the first,
  so a caller can show them together rather than one per attempt.

  Possible codes:

    * `:deprecated` - the tag itself is registered but deprecated
    * `:subtag_deprecated` - a subtag is deprecated
    * `:no_language` - the tag does not begin with a language subtag
    * `:unknown` - a code is not in the registry
    * `:too_long` - a private-use subtag exceeds 8 characters
    * `:extra_language`, `:extra_extlang`, `:extra_script`, `:extra_region` -
      a subtag type that may appear only once appears more than once
    * `:duplicate_variant` - the same variant subtag appears twice
    * `:wrong_order` - subtags are not in the order required by the ABNF
    * `:suppress_script` - the script subtag is the language's default and
      should be omitted

  ## Examples

      iex> LangTags.Tag.errors("en-GB")
      []

      iex> [error] = LangTags.Tag.errors("art-lojban")
      iex> error.code
      :deprecated

      iex> [error] = LangTags.Tag.errors("en-en")
      iex> {error.code, error.subtag}
      {:extra_language, "en"}

      iex> [error] = LangTags.Tag.errors("gsw-Latn")
      iex> error.message
      "the script subtag 'latn' is the default for language 'gsw' and should be omitted"

  """
  @spec errors(map | String.t()) :: [error]
  def errors(tag) when is_binary(tag), do: tag |> new() |> errors()

  def errors(tag) when is_map(tag) do
    # Grandfathered and redundant tags are registered as a whole, so they are
    # judged as a whole rather than decomposed into subtags.
    case tag["Record"] do
      nil ->
        subtag_errors(tag)

      %{"Deprecated" => date} ->
        [error(:deprecated, tag["Tag"], "the tag '#{tag["Tag"]}' is deprecated as of #{date}")]

      _registered ->
        []
    end
  end

  defp subtag_errors(tag) do
    # Everything from the first singleton onwards is an extension or a
    # private-use sequence and is not classified as a subtag.
    {codes, private} =
      tag["Tag"] |> String.split("-") |> Enum.split_while(&(String.length(&1) > 1))

    classified = codes |> Enum.with_index() |> Enum.map(fn {code, i} -> classify(code, i) end)

    Enum.concat([
      private_use_errors(private),
      unknown_errors(classified),
      no_language_errors(classified),
      deprecated_subtag_errors(classified),
      extra_subtag_errors(classified),
      duplicate_variant_errors(classified),
      order_errors(classified),
      suppress_script_errors(classified)
    ])
  end

  defp classify(code, index) do
    available = Registry.types(code)

    %{
      code: code,
      type: Enum.find(candidate_types(index, String.length(code)), &(&1 in available)),
      known?: available != []
    }
  end

  # A language subtag may only appear at the front of a tag; anywhere else its
  # type would be indeterminate. These mirror the assumptions `subtags/1`
  # makes, so classification and validation agree.
  defp candidate_types(0, _length), do: ["language"]
  # Should be a region, but a misplaced language subtag is possible.
  defp candidate_types(_index, 2), do: ["region", "language"]
  # Could be a numeric region code, e.g. "001" for World.
  defp candidate_types(_index, 3), do: ["region", "extlang", "language"]
  # Could be a numeric variant.
  defp candidate_types(_index, 4), do: ["variant", "script"]
  defp candidate_types(_index, _length), do: ["variant"]

  # The limit applies to each component, not to the sequence as a whole, so
  # "en-x-more-than-eight-chars" is fine but "en-x-morethaneightchars" is not.
  defp private_use_errors([]), do: []

  defp private_use_errors([_singleton | components]) do
    for code <- components, String.length(code) > 8 do
      error(:too_long, code, "the private-use subtag '#{code}' is longer than 8 characters")
    end
  end

  defp unknown_errors(classified) do
    for %{known?: false, code: code} <- classified do
      error(:unknown, code, "'#{code}' is not registered")
    end
  end

  # A tag made up only of a private-use sequence, such as "x-local", has no
  # language subtag and does not need one.
  defp no_language_errors([]), do: []
  defp no_language_errors([%{type: "language"} | _rest]), do: []

  defp no_language_errors([%{code: code} | _rest]) do
    [error(:no_language, code, "the tag does not begin with a language subtag")]
  end

  defp deprecated_subtag_errors(classified) do
    for %{type: type, code: code} when not is_nil(type) <- classified,
        date = Registry.subtag(code, type)["Deprecated"] do
      error(:subtag_deprecated, code, "the #{type} subtag '#{code}' is deprecated as of #{date}")
    end
  end

  defp extra_subtag_errors(classified) do
    Enum.flat_map(@singular_types, fn {type, code} ->
      classified
      |> Enum.filter(&(&1.type == type))
      |> extras_after_first(type, code)
    end)
  end

  defp extras_after_first([_first, _second | _rest] = found, type, code) do
    for %{code: subtag} <- tl(found) do
      error(code, subtag, "extra #{type} subtag '#{subtag}' found")
    end
  end

  defp extras_after_first(_none_or_one, _type, _code), do: []

  defp duplicate_variant_errors(classified) do
    classified
    |> Enum.filter(&(&1.type == "variant"))
    |> Enum.frequencies_by(& &1.code)
    |> Enum.filter(fn {_code, count} -> count > 1 end)
    |> Enum.sort()
    |> Enum.map(fn {code, _count} ->
      error(:duplicate_variant, code, "duplicate variant subtag '#{code}' found")
    end)
  end

  defp order_errors(classified) do
    classified
    |> Enum.filter(& &1.type)
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.filter(fn [before, subtag] -> @ranks[before.type] > @ranks[subtag.type] end)
    |> Enum.map(fn [_before, subtag] ->
      error(
        :wrong_order,
        subtag.code,
        "the #{subtag.type} subtag '#{subtag.code}' is out of order"
      )
    end)
  end

  # A script subtag that merely restates the language's default adds nothing.
  # See RFC 5646 section 3.1.9.
  defp suppress_script_errors(classified) do
    with %{code: language} <- Enum.find(classified, &(&1.type == "language")),
         suppress when is_binary(suppress) <-
           Registry.subtag(language, "language")["Suppress-Script"],
         script = String.downcase(suppress),
         %{code: ^script} <- Enum.find(classified, &(&1.type == "script" and &1.code == script)) do
      [
        error(
          :suppress_script,
          script,
          "the script subtag '#{script}' is the default for language '#{language}' and should be omitted"
        )
      ]
    else
      _no_redundant_script -> []
    end
  end

  defp error(code, subtag, message) do
    %{code: code, subtag: subtag, message: message}
  end

  @doc """
  Returns "grandfathered" if the tag is grandfathered, "redundant" if the tag is redundant, and "tag" if neither.

  For a definition of grandfathered and redundant tags, see [RFC 5646 section 2.2.8](http://tools.ietf.org/html/rfc5646#section-2.2.8).

  ## Examples

      iex> LangTags.Tag.type("art-lojban")
      "grandfathered"
      iex> LangTags.Tag.type("az-Arab")
      "redundant"

  """
  @spec type(map | String.t()) :: String.t()
  def type(tag) when is_map(tag), do: tag["Record"]["Type"] || "tag"
  def type(tag) when is_binary(tag), do: tag |> new() |> type()

  @doc """
  Returns `true` if the tag is grandfathered, otherwise returns `false`

  ## Examples

      iex> LangTags.Tag.grandfathered?("zh-xiang")
      true
      iex> LangTags.Tag.grandfathered?("az-Arab")
      false

  """
  @spec grandfathered?(String.t()) :: boolean
  def grandfathered?(tag), do: Registry.grandfathered?(tag)

  @doc """
  Returns `true` if the tag is redundant, otherwise returns `false`

  ## Examples

      iex> LangTags.Tag.redundant?("az-Arab")
      true
      iex> LangTags.Tag.redundant?("zh-xiang")
      false

  """
  @spec redundant?(String.t()) :: boolean
  def redundant?(tag), do: Registry.redundant?(tag)

  @doc """
  For grandfathered or redundant tags, returns a date string reflecting the date the tag was added to the registry.

  ## Examples

      iex> LangTags.Tag.added("cel-gaulish")
      "2001-05-25"

  """
  @spec added(map | String.t()) :: String.t() | nil
  def added(tag) when is_map(tag), do: tag["Record"]["Added"]
  def added(tag) when is_binary(tag), do: tag |> new() |> added()

  @doc """
  For grandfathered or redundant tags, returns a date string reflecting the deprecation date if the tag is deprecated.

  ## Examples

      iex> LangTags.Tag.deprecated("art-lojban")
      "2003-09-02"
      iex> "zh-cmn-Hant" |> LangTags.Tag.new() |> LangTags.Tag.deprecated()
      "2009-07-29"

  """
  @spec deprecated(map | String.t()) :: String.t() | nil
  def deprecated(tag) when is_map(tag), do: tag["Record"]["Deprecated"]
  def deprecated(tag) when is_binary(tag), do: tag |> new() |> deprecated()

  @doc """
  Returns a list of tag descriptions for grandfathered or redundant tags, otherwise returns an empty list.

  ## Examples

      iex> LangTags.Tag.descriptions("art-lojban")
      ["Lojban"]

  """
  @spec descriptions(map | String.t()) :: String.t() | []
  def descriptions(tag) when is_map(tag), do: tag["Record"]["Description"] || []
  def descriptions(tag) when is_binary(tag), do: tag |> new() |> descriptions()

  @doc """
  Format a tag according to the case conventions defined in [RFC 5646 section 2.1.1](http://tools.ietf.org/html/rfc5646#section-2.1.1).

  ## Examples

      iex> LangTags.Tag.format("en-gb-oed")
      "en-GB-oed"
      iex> "en-gb" |> LangTags.Tag.new() |> LangTags.Tag.format()
      "en-GB"

  """
  @spec format(map | String.t()) :: String.t()
  def format(tag) when is_binary(tag), do: tag |> new() |> format()

  def format(tag) when is_map(tag) do
    tag["Tag"]
    |> String.split("-")
    |> Enum.with_index()
    |> Enum.reduce([], fn {value, index}, acc ->
      format_by_index(index, value, acc)
    end)
    |> Enum.reverse()
    |> Enum.join("-")
  end

  ## Helpers
  defp process_subtags(_tag, "grandfathered"), do: []

  defp process_subtags(tag, _) do
    codes = tag["Tag"] |> String.split("-") |> Enum.with_index()

    subtags =
      Enum.reduce_while(codes, [], fn {code, index}, subtags ->
        # Singletons and anything after are unhandled.
        if String.length(code) < 2 do
          # Stop the loop (stop processing after a singleton).
          {:halt, subtags}
        else
          subtags = process_subtag_by_index(index, code, subtags)
          {:cont, subtags}
        end
      end)

    Enum.reverse(subtags)
  end

  defp format_by_index(0, value, _acc), do: [value]

  defp format_by_index(_index, value, acc) do
    if acc |> hd() |> String.length() == 1 do
      [value | acc]
    else
      format_by_string_length(acc, value)
    end
  end

  defp format_by_string_length(acc, value) do
    case String.length(value) do
      2 ->
        [String.upcase(value) | acc]

      4 ->
        [String.capitalize(value) | acc]

      _ ->
        [value | acc]
    end
  end

  ## Process subtags
  defp process_subtag_by_index(0, code, subtags) do
    # Language subtags may only appear at the beginning of the tag, otherwise the subtag type is indeterminate.
    if subtag = SubTag.find(code, "language"), do: [subtag | subtags], else: subtags
  end

  defp process_subtag_by_index(_, code, subtags) do
    code |> String.length() |> process_subtag_by_string_length(code, subtags)
  end

  defp process_subtag_by_string_length(2, code, subtags) do
    # Should be a region, but, in case of error we can assume
    # a language type in the wrong place
    types = ["region", "language"]
    find_subtag(code, subtags, types)
  end

  defp process_subtag_by_string_length(3, code, subtags) do
    # Could be a numeric region code e.g. '001' for 'World'
    # As a second case we try with "extlang"
    # Error case: language subtag in the wrong place.
    types = ["region", "extlang", "language"]
    find_subtag(code, subtags, types)
  end

  defp process_subtag_by_string_length(4, code, subtags) do
    # Could be a numeric variant.
    types = ["variant", "script"]
    find_subtag(code, subtags, types)
  end

  defp process_subtag_by_string_length(_, code, subtags) do
    # Should be a variant
    find_subtag(code, subtags, ["variant"])
  end

  defp find_subtag(code, subtags, types) do
    Enum.reduce_while(types, subtags, fn type, acc ->
      if subtag = SubTag.find(code, type) do
        {:halt, [subtag | acc]}
      else
        {:cont, acc}
      end
    end)
  end
end
