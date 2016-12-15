defmodule LangTags do
  @moduledoc """
  Language Tags
  """

  alias LangTags.{Registry,Tag}

  @spec tags(String.t) :: map
  def tags(tag), do: Tag.new(tag)

  @doc """
  Shortcut for `LangTags.Tag.valid?/1`. Return `true` if the tag is valid, `false` otherwise.

  For meaningful error output see `errors/1`.
  """
  @spec check(map) :: boolean
  def check(tag), do: Tag.valid?(tag)

  @doc """
  Look up for one or more types for the given string.

  Returns an empty list if the does not have any type or if the available types
  are: *grandfathered* or *redundant*.

  By default, the types *grandfathered* or *redundant* are excluded from the
  result. Set the `all` parameter to `true` to include them.

  ## Examples

  iex> LangTags.types("en")
  ["language"]
  iex> LangTags.types("xml")
  ["extlang", "language"]
  iex> LangTags.types("dummy")
  []

  """
  @spec types(String.t) :: [String.t] | []
  def types(subtag, all \\ false) do
    type_info = Registry.types()[subtag]

    if is_map(type_info) do
      type_info |> MapSet.to_list() |> process_types(all)
    else
      []
    end
  end

  defp process_types(type_info, true), do: type_info
  defp process_types(type_info, false) do
    Enum.filter(type_info, fn(t) -> t != "grandfathered" && t != "redundant" end)
  end

  @doc """
  Look up one or more subtags. Returns a list of subtag maps. Returns an empty list if all of the subtags are non-existent.

  ## Examples

  Calling `LangTags.subtags("mt")` will return an array with 2 subtag maps: one for Malta (the 'region' type subtag) and
  one for Maltese (the 'language' type subtag).


    iex> LangTags.subtags("mt")
    # [Subtag, Subtag]
    iex> LangTags.subtags("bumblebee")
    []


  To get or check a single subtag by type use `language/1`, `region/1` or `type/2`.
  """
  def subtags(_subtags) do
    # TODO: Implement
  end

  @doc """
  The opposite of `subtags/1`. Returns a list of codes that are not registered subtags, otherwise returns an empty array.

  ## Examples

    iex> LangTags.filter(["en", "Aargh"])
      ['Aargh']

  """
  def filter(_subtags) do
    # TODO: Implement
  end

  @doc """
  Search for tags and subtags by description.

  Supports either a RegExp or a string for `description`. Returns a list
  of `Subtag` and `Tag` maps or an empty list if no results were found.

  Note that `Tag` map in the results represent 'grandfathered' or 'redundant'
  tags. These are excluded by default. Set the `all` parameter to `true`
  to include them.

  Search is case-insensitive if `description` is a string.
  """
  def search(_query, _all) do
    # TODO: Implement
  end

  @doc """
  Returns alist  of subtag maps representing all the *language* type subtags belonging to the given *macrolanguage* type subtag.

  Throws an error if `macrolanguage` is not a macrolanguage.

  ## Examples

  iex> LangTags.languages("zh")
  # [Subtag, Subtag...]
  iex> LangTags.languages("en");
  Error: 'en' is not a valid macrolanguage.

  """
  def languages(_macrolanguage) do
    # TODO: Implement
  end

  @doc """
  Convenience method to get a single *language* type subtag. Returns a subtag map or `nil`.

  ## Examples

    iex> LangTags.language("en")
    # Subtag
    iex> tags.language("us")
    nil

  """
  @spec language(String.t) :: map | nil
  def language(subtag), do: type(subtag, "language")

  @doc """
  As `language/1`, but with *region* type subtags.

  ## Examples

    iex> LangTags.region("mt")
    # Subtag
    iex> LangTags.region("en");
    nil

  """
  @spec region(String.t) :: map | nil
  def region(subtag), do: type(subtag, "region")

  @doc """
  Get a subtag by type. Returns the subtag matching `type` as a subtag map otherwise returns `nil`.

  A `type` consists of one of the following strings: *language*, *extlang*,
  *script*, *region* or *variant*. To get a *grandfathered* or *redundant* type
  tag use `tags/1`.

  ## Examples

    iex> LangTags.type("zh", "language")
    # SubTag
    iex> LangTags.type("zh", "script")
    nil

  """
  @spec type(String.t, String.t) :: map | nil
  def type(subtag, type) when type in ["language", "extlang", "script", "region", "variant"] do
    subtag = String.downcase(subtag)
    Tag.find_subtag(subtag, type)
  end

  @doc """
  Returns the file date for the underlying data, as a string.
  """
  @spec date() :: String.t
  def date, do: Registry.date()
end
