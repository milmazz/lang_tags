defmodule LangTags.Tag do
  @moduledoc """
  Tag
  """

  alias LangTags.{SubTag,Registry}

  @doc """
  Creates a new tag as a map
  """
  @spec new(String.t) :: map
  def new(tag) do
    # Lowercase for consistency (case is only a formatting
    # convention, not a standard requirement)
    tag = tag |> String.trim() |> String.downcase()

    try do
      %{"Tag" => tag, "Record" => Registry.tag(tag)}
    rescue
      RuntimeError -> %{"Tag" => tag}
    end
  end

  @doc """
  If the tag is listed as *deprecated* or *redundant* it might have a preferred value. This method returns a tag as a map if so.

  ## Examples

    iex> preferred("art-lojban")
    %{"Tag" => "jbo"}
    iex> "zh-cmn-Hant" |> new() |> preferred()
    %{"Tag" => "cmn-hant"}

  """
  @spec preferred(map | String.t) :: String.t | nil
  def preferred(tag) when is_binary(tag), do: tag |> new() |> preferred()
  def preferred(tag) when is_map(tag) do
    preferred = tag["Record"]["Preferred-Value"]

    if preferred, do: new(preferred), else: nil
  end

  @doc """
  Returns a list of subtags making up the tag, as `Subtag` maps.

  Note that if the tag is *grandfathered* the result will be an empty list
  """
  @spec subtags(map | String.t) :: [map] | []
  def subtags(tag) when is_map(tag), do: process_subtags(tag, tag["Record"]["Type"])
  def subtags(tag) when is_binary(tag), do: tag |> new() |> subtags()

  defp process_subtags(_tag, "grandfathered"), do: []

  defp process_subtags(tag, _) do
    codes = tag["Tag"] |> String.split("-") |> Enum.with_index()

    subtags =
      Enum.reduce_while(codes, [], fn({code, index}, subtags) ->
        # Singletons and anything after are unhandled.
        if String.length(code) < 2 do
          {:halt, subtags} # Stop the loop (stop processing after a singleton).
        else
          subtags = process_subtag_by_index(index, code, subtags)
          {:cont, subtags}
        end
      end)
    Enum.reverse(subtags)
  end

  @doc """
  Shortcut for `find/2` with a `language` filter
  """
  @spec language(map | String.t) :: map
  def language(tag) when is_map(tag), do: find(tag, "language")
  def language(tag) when is_binary(tag), do: tag |> new() |> language()

  @doc """
  Shortcut for `find/2` with a `region` filter
  """
  @spec region(map | String.t) :: map
  def region(tag) when is_map(tag), do: find(tag, "region")
  def region(tag) when is_binary(tag), do: tag |> new() |> region()

  @doc """
  Shortcut for `find/2` with a `script` filter
  """
  @spec script(map | String.t) :: map
  def script(tag) when is_map(tag), do: find(tag, "script")
  def script(tag) when is_binary(tag), do: tag |> new() |> script()

  @doc """
  Find a subtag of the given type from those making up the tag.
  """
  @spec find(map | String.t, String.t) :: map
  def find(tag, filter) when is_map(tag), do: Enum.find(subtags(tag), &(type(&1) == filter))
  def find(tag, filter) when is_binary(tag), do: tag |> new() |> find(filter)

  @doc """
  Returns `true` if the tag is valid, `false` otherwise.
  """
  @spec valid?(map | String.t) :: boolean
  def valid?(tag) when is_map(tag), do: errors(tag) == []
  def valid?(tag) when is_binary(tag), do: tag |> new |> valid?()

  # FIXME: This is horrible!
  def errors(tag) do
    # Check if the tag is grandfathered and if the grandfathered tag is deprecated (e.g. no-nyn).
    if tag["Record"]["Deprecated"] do
      ["ERR_DEPRECATED"]
    else
      codes = tag["Tag"] |> String.split("-")

      # Check that all subtag codes are meaningful.
      errors =
        codes
        |> Enum.with_index()
        |> Enum.reduce_while([], fn({code, index}, acc) ->
            # Ignore anything after a singleton
            if String.length(code) < 2 do
              # Check that each private-use subtag is within the maximum allowed length.
              acc =
                codes
                |> Enum.slice(index, Enum.count(codes))
                |> Enum.reduce_while(acc, fn(c, result) ->
                      if String.length(c) > 8 do
                        {:halt, ["ERR_TOO_LONG" | result]}
                      else
                        {:cont, result}
                      end
                    end)

                {:halt, acc}
            else
              if Registry.types(code) == [] do
                {:halt, ["ERR_UNKNOWN" | acc]}
              else
                {:cont, acc}
              end
            end
          end)

      # Check that first tag is a language tag.
      subtags = subtags(tag)
      errors =
        if subtags |> List.first() |> SubTag.type() == "language" do
          ["ERR_NO_LANGUAGE" | errors]
        else
           # TODO: Check for more than one of some types and for deprecation.
           # TODO: Check for correct order.
          errors
        end
    end
  end

  @doc """
  Returns "grandfathered" if the tag is grandfathered, "redundant" if the tag is redundant, and "tag" if neither.

  For a definition of grandfathered and redundant tags, see [RFC 5646 section 2.2.8](http://tools.ietf.org/html/rfc5646#section-2.2.8).

  ## Examples

    iex> type("art-lojban")
    "grandfathered"
    iex> type("az-Arab")
    "redundant"

  """
  @spec type(map | String.t) :: String.t
  def type(tag) when is_map(tag), do: tag["Record"]["Type"] || "tag"
  def type(tag) when is_binary(tag), do: tag |> new() |> type()

  @doc """
  Returns `true` if the tag is grandfathered, otherwise returns `false`

  ## Examples

    iex> grandfathered?("zh-xiang")
    true
    iex> grandfathered?("az-Arab")
    false

  """
  @spec grandfathered?(String.t) :: boolean
  def grandfathered?(tag), do: Registry.grandfathered?(tag)

  @doc """
  Returns `true` if the tag is redundant, otherwise returns `false`

  ## Examples

    iex> redundant?("az-Arab")
    true
    iex> redundant?("zh-xiang")
    false

  """
  @spec redundant?(String.t) :: boolean
  def redundant?(tag), do: Registry.redundant?(tag)

  @doc """
  For grandfathered or redundant tags, returns a date string reflecting the date the tag was added to the registry.

  ## Examples

    iex> added("cel-gaulish")
    "2001-05-25"

  """
  @spec added(map | String.t) :: String.t | nil
  def added(tag) when is_map(tag), do: tag["Record"]["Added"]
  def added(tag) when is_binary(tag), do: tag |> new() |> added()

  @doc """
  For grandfathered or redundant tags, returns a date string reflecting the deprecation date if the tag is deprecated.

  ## Examples

    iex> deprecated("art-lojban")
    "2003-09-02"
    iex> "zh-cmn-Hant" |> new() |> deprecated()
    "2009-07-29"

  """
  @spec deprecated(map | String.t) :: String.t | nil
  def deprecated(tag) when is_map(tag), do: tag["Record"]["Deprecated"]
  def deprecated(tag) when is_binary(tag), do: tag |> new() |> deprecated()

  @doc """
  Returns a list of tag descriptions for grandfathered or redundant tags, otherwise returns an empty list.

  ## Examples

    iex> descriptions("art-lojban")
    ["Lojban"]

  """
  @spec descriptions(map | String.t) :: String.t | []
  def descriptions(tag) when is_map(tag), do: tag["Record"]["Description"] || []
  def descriptions(tag) when is_binary(tag), do: tag |> new() |> descriptions()

  @doc """
  Format a tag according to the case conventions defined in [RFC 5646 section 2.1.1](http://tools.ietf.org/html/rfc5646#section-2.1.1).

  ## Examples

    iex> format("en-gb-oed")
    "en-GB-oed"
    iex> "en-gb" |> new() |> format()
    "en-GB"

  """
  @spec format(map | String.t) :: String.t
  def format(tag) when is_binary(tag), do: tag |> new() |> format()
  def format(tag) when is_map(tag) do
    (tag["Tag"])
    |> String.split("-")
    |> Enum.with_index()
    |> Enum.reduce([], fn({value, index}, acc) ->
        format_by_index(index, value, acc)
       end)
    |> Enum.reverse()
    |> Enum.join("-")
  end

  ## Helpers
  defp format_by_index(0, value, _acc), do: [value]

  defp format_by_index(_index, value, acc) do
    if (acc |> hd() |> String.length() == 1) do
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
        {char, rest} = String.Casing.titlecase_once(value)
        [char <> rest | acc]
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
    Enum.reduce_while(types, subtags, fn(type, acc) ->
      if subtag = SubTag.find(code, type) do
        {:halt, [subtag | acc]}
      else
        {:cont, acc}
      end
    end)
  end
end
