defmodule LangTags.Tag do
  @moduledoc """
  Tag
  """

  alias LangTags.Registry
  alias LangTags.SubTag

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
  If the tag is listed as *deprecated* or *redundant* it might have a preferred value. This method returns a tag as a map object if so.

  ## Examples

    iex> new("zh-cmn-Hant") |> preferred()
    %{"Tag" => "cmn-hant"}
  """
  @spec preferred(map) :: String.t | nil
  def preferred(tag) do
    preferred = tag["Record"]["Preferred-Value"]

    if preferred, do: new(preferred), else: nil
  end

  @doc """
  Returns a list of subtags making up the tag, as `Subtag` maps.

  Note that if the tag is *grandfathered* the result will be an empty list
  """
  @spec subtags(map) :: [map] | []
  def subtags(tag), do: process_subtags(tag, tag["Record"]["Type"])

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
  @spec language(map) :: map
  def language(tag), do: find(tag, "language")

  @doc """
  Shortcut for `find/2` with a `region` filter
  """
  @spec region(map) :: map
  def region(tag), do: find(tag, "region")

  @doc """
  Shortcut for `find/2` with a `script` filter
  """
  @spec script(map) :: map
  def script(tag), do: find(tag, "script")

  @doc """
  Find a subtag of the given type from those making up the tag.
  """
  @spec find(map, String.t) :: map
  def find(tag, filter), do: Enum.find(subtags(tag), &(type(&1) == filter))

  @doc """
  Returns `true` if the tag is valid, `false` otherwise.
  """
  @spec valid?(map) :: boolean
  def valid?(tag) do
    errors(tag) == []
  end

  def errors(%{"Record" => record}) do
    # Check if the tag is grandfathered and if the grandfathered tag is deprecated (e.g. no-nyn).
    if record["Deprecated"] do
      ["ERR_DEPRECATED"]
    else
      []
    end
  end

  # TODO: Needs to be implemented
  def errors(tag) do
    # Check that all subtag codes are meaningful.
    tag["Tag"]
    |> String.split("-")
    |> Enum.any?(fn(_subtag) ->
        # Ignore anything after a singleton
        false
       end)
  end

  # FIXME: Review section 2.2.8, implementation does not match with docs.
  @doc """
  Returns `grandfathered` if the tag is grandfathered, `redundant` if the tag is redundant, and `tag` if neither.

  For a definition of grandfathered and redundant tags, see [RFC 5646 section 2.2.8](http://tools.ietf.org/html/rfc5646#section-2.2.8).
  """
  @spec type(map) :: String.t
  def type(tag), do: tag["Record"]["Type"] || "tag"

  @doc """
  For grandfathered or redundant tags, returns a date string reflecting the date the tag was added to the registry.
  """
  @spec added(map) :: String.t | nil
  def added(tag), do: tag["Record"]["Added"]

  @doc """
  For grandfathered or redundant tags, returns a date string reflecting the deprecation date if the tag is deprecated.

  ## Examples

    iex> new("zh-cmn-Hant") |> deprecated()
    "2009-07-29"

  """
  @spec deprecated(map) :: String.t | nil
  def deprecated(tag), do: tag["Record"]["Deprecated"]

  @doc """
  Returns a list of tag descriptions for grandfathered or redundant tags, otherwise returns an empty list.
  """
  @spec descriptions(map) :: String.t | []
  def descriptions(tag), do: tag["Record"]["Description"] || []

  @doc """
  Format a tag according to the case conventions defined in [RFC 5646 section 2.1.1](http://tools.ietf.org/html/rfc5646#section-2.1.1).

  ## Examples

    iex> new("en-gb") |> format()
    "en-GB"

  """
  @spec format(map) :: String.t
  def format(tag) do
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
  @doc false
  def find_subtag(code, type) do
    try do
      SubTag.new(code, type)
    rescue
      RuntimeError -> nil
    end
  end

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
    if subtag = find_subtag(code, "language"), do: [subtag | subtags], else: subtags
  end

  defp process_subtag_by_index(_, code, subtags) do
    code |> String.length() |> process_subtag_by_string_length(code, subtags)
  end

  defp process_subtag_by_string_length(2, code, subtags) do
    # Should be a region
    if subtag = find_subtag(code, "region") do
      [subtag | subtags]
    else
      # Error case: language subtag in the wrong place.
      if subtag = find_subtag(code, "language") do
        [subtag | subtags]
      else
        subtags
      end
    end
  end

  defp process_subtag_by_string_length(3, code, subtags) do
    # Could be a numeric region code e.g. '001' for 'World'
    if subtag = find_subtag(code, "region") do
      [subtag | subtags]
    else
      if subtag = find_subtag(code, "extlang") do
        [subtag | subtags]
      else
        # Error case: language subtag in the wrong place.
        if subtag = find_subtag(code, "language") do
          [subtag | subtags]
        else
          subtags
        end
      end
    end
  end

  defp process_subtag_by_string_length(4, code, subtags) do
    # Could be a numeric variant.
    if subtag = find_subtag(code, "variant") do
      [subtag | subtags]
    else
      if subtag = find_subtag(code, "script") do
        [subtag | subtags]
      else
        subtags
      end
    end
  end

  defp process_subtag_by_string_length(_, code, subtags) do
    # Should be a variant
    if subtag = find_subtag(code, "variant") do
      [subtag | subtags]
    else
      subtags
    end
  end
end
