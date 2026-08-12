defmodule LangTags do
  @moduledoc """
  The Language Tag according to the [BCP47](https://tools.ietf.org/html/bcp47)

  Language tags are used to help identify languages, whether spoken, written,
  signed, or otherwise signaled, for the purpose of communication.  This
  includes constructed and artificial languages but excludes languages not
  intended primarily for human communication, such as programming languages.

  For more information, see [BCP47](https://tools.ietf.org/html/bcp47)
  """

  alias LangTags.Registry
  alias LangTags.SubTag
  alias LangTags.Tag

  @doc """
  Shortcut for `LangTags.Tag.new/1`

  ## Examples

      iex> LangTags.tags("art-lojban") == LangTags.Tag.new("art-lojban")
      true

  """
  @spec tags(String.t()) :: map
  def tags(tag), do: Tag.new(tag)

  @doc """
  Shortcut for `LangTags.Tag.valid?/1`. Returns `true` if the tag is valid, `false` otherwise.

  For meaningful error output see `errors/1`.
  """
  @spec check(map | String.t()) :: boolean
  def check(tag) when is_map(tag), do: Tag.valid?(tag)
  def check(tag) when is_binary(tag), do: tag |> tags() |> check()

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
      iex> LangTags.types("art-lojban")
      []
      iex> LangTags.types("art-lojban", true)
      ["grandfathered"]

  """
  @spec types(String.t()) :: [String.t()] | []
  def types(subtag, all \\ false) do
    type_info = subtag |> String.downcase() |> Registry.types()

    if type_info == [], do: [], else: process_types(type_info, all)
  end

  defp process_types(type_info, true), do: type_info

  defp process_types(type_info, false) do
    Enum.filter(type_info, fn t -> t != "grandfathered" && t != "redundant" end)
  end

  @doc """
  Look up one or more subtags. Returns a list of subtag maps. Returns an empty list if all of the subtags are non-existent.

  ## Examples

  Calling `LangTags.subtags("mt")` will return an array with 2 subtag maps: one
  for Malta (the 'region' type subtag) and one for Maltese (the 'language' type
  subtag).

      iex> for subtag <- LangTags.subtags("mt"), do: subtag["Record"]["Description"]
      [["Maltese"], ["Malta"]]
      iex> LangTags.subtags(["mt", "ca"]) |> Enum.count()
      4
      iex> LangTags.subtags("bumblebee")
      []

  To get or check a single subtag by type use `language/1`, `region/1` or
  `type/2`.
  """
  @spec subtags(String.t() | [String.t()]) :: [map]
  def subtags(key) when is_binary(key), do: subtags([key])

  def subtags(keys) when is_list(keys) do
    Enum.flat_map(keys, fn key ->
      key
      |> String.downcase()
      |> types()
      |> Enum.map(fn type -> SubTag.new(key, type) end)
    end)
  end

  @doc """
  The opposite of `subtags/1`. Returns a list of codes that are not registered subtags, otherwise returns an empty array.

  ## Examples

      iex> LangTags.filter(["en", "Aargh"])
      ["Aargh"]

  """
  @spec filter(String.t() | [String.t()]) :: [String.t()]
  def filter(subtag) when is_binary(subtag), do: filter([subtag])

  def filter(subtags) when is_list(subtags) do
    Enum.filter(subtags, fn key ->
      key |> String.downcase() |> types() == []
    end)
  end

  @doc """
  Search for tags and subtags by description.

  Supports either a `Regex` or a string for `description`. Returns a list of
  subtag and tag maps, or an empty list if no results were found.

  Search is case-insensitive when `description` is a string, and matches on
  any part of a description. Entries whose description matches the query
  exactly are returned first; the rest follow in registry order.

  Note that tag maps in the results represent *grandfathered* or *redundant*
  tags. These are excluded by default. Set the `all` parameter to `true` to
  include them.

  ## Examples

      iex> LangTags.search("Maltese") |> Enum.map(&LangTags.SubTag.format/1)
      ["mt", "mdl", "mdl"]

      iex> LangTags.search(~r/^Klingon$/) |> Enum.map(&LangTags.SubTag.format/1)
      ["tlh"]

      iex> LangTags.search("Gibberish")
      []

  """
  @spec search(String.t() | Regex.t(), boolean) :: [map]
  def search(description, all \\ false) do
    subtags =
      for {key, type} <- Registry.subtag_keys(),
          descriptions = descriptions(Registry.subtag(key, type)),
          matches?(descriptions, description),
          do: {SubTag.new(key, type), exact?(descriptions, description)}

    tags =
      for key <- tag_keys(all),
          descriptions = descriptions(Registry.tag(key)),
          matches?(descriptions, description),
          do: {Tag.new(key), exact?(descriptions, description)}

    {exact, partial} = Enum.split_with(subtags ++ tags, fn {_result, exact?} -> exact? end)

    Enum.map(exact ++ partial, fn {result, _exact?} -> result end)
  end

  defp tag_keys(true), do: Registry.tag_keys()
  defp tag_keys(false), do: []

  defp descriptions(record), do: record["Description"] || []

  defp matches?(descriptions, %Regex{} = description) do
    Enum.any?(descriptions, &Regex.match?(description, &1))
  end

  defp matches?(descriptions, description) when is_binary(description) do
    description = String.downcase(description)
    Enum.any?(descriptions, &String.contains?(String.downcase(&1), description))
  end

  # Exactness only makes sense for a literal string; a pattern that matched at
  # all has already said everything it can about how well it matched.
  defp exact?(_descriptions, %Regex{}), do: false

  defp exact?(descriptions, description) when is_binary(description) do
    description = String.downcase(description)
    Enum.any?(descriptions, &(String.downcase(&1) == description))
  end

  @doc """
  Returns a list of subtag maps representing all the *language* type subtags belonging to the given *macrolanguage* type subtag.

  Throws an error if `macrolanguage` is not a macrolanguage.

  ## Examples

      iex> LangTags.languages("zh") |> Enum.count()
      38
      iex> LangTags.languages("en")
      ** (ArgumentError) 'en' is not a valid macrolanguage.

  """
  @spec languages(String.t()) :: [map] | Exception.t()
  def languages(macrolanguage) do
    macrolanguage = String.downcase(macrolanguage)

    if SubTag.macrolanguage?(macrolanguage) do
      macrolanguage
      |> Registry.macrolanguages()
      |> Enum.reduce([], fn {subtag, type}, acc ->
        [SubTag.new(subtag, type) | acc]
      end)
    else
      raise(ArgumentError, "'#{macrolanguage}' is not a valid macrolanguage.")
    end
  end

  @doc """
  Convenience method to get a single *language* type subtag. Returns a subtag map or `nil`.

  ## Examples

      iex> LangTags.language("en")
      %{"Record" => %{"Added" => "2005-10-16", "Description" => ["English"],
          "Subtag" => "en", "Suppress-Script" => "Latn", "Type" => "language"},
        "Subtag" => "en"}
      iex> LangTags.language("us")
      nil

  """
  @spec language(String.t()) :: map | nil
  def language(subtag), do: type(subtag, "language")

  @doc """
  As `language/1`, but with *region* type subtags.

  ## Examples

      iex> LangTags.region("mt")
      %{"Record" => %{"Added" => "2005-10-16", "Description" => ["Malta"],
          "Subtag" => "mt", "Type" => "region"}, "Subtag" => "mt"}
      iex> LangTags.region("en")
      nil

  """
  @spec region(String.t()) :: map | nil
  def region(subtag), do: type(subtag, "region")

  @doc """
  As `language/1`, but with *script* type subtags.

  ## Examples

      iex> LangTags.script("aghb")
      %{"Record" => %{"Added" => "2012-11-01",
          "Description" => ["Caucasian Albanian"], "Subtag" => "aghb",
          "Type" => "script"}, "Subtag" => "aghb"}
      iex> LangTags.script("en")
      nil

  """
  @spec script(String.t()) :: map | nil
  def script(subtag), do: type(subtag, "script")

  @doc """
  Get a subtag by type. Returns the subtag matching `type` as a subtag map otherwise returns `nil`.

  A `type` consists of one of the following strings: *language*, *extlang*,
  *script*, *region* or *variant*. To get a *grandfathered* or *redundant* type
  tag use `tags/1`.

  ## Examples

      iex> LangTags.type("zh", "language") == LangTags.language("zh")
      true
      iex> LangTags.type("zh", "script")
      nil

  """
  @spec type(String.t(), String.t()) :: map | nil
  def type(subtag, type) when type in ["language", "extlang", "script", "region", "variant"] do
    SubTag.find(subtag, type)
  end

  @doc """
  Returns every registered subtag of the given type, as `{code, type}` pairs.

  A `type` consists of one of the following strings: *language*, *extlang*,
  *script*, *region* or *variant*. Grandfathered and redundant records are
  tags rather than subtags and are not returned.

  Pairs come back in the order they appear in the registry, and include
  deprecated subtags, which are still registered. Only the codes are
  returned: pass one to `type/2` or `subtags/1` to read its full record,
  so that listing the registry does not build every record up front.

  ## Examples

      iex> {"latn", "script"} in LangTags.all("script")
      true
      iex> LangTags.all("region") |> List.keyfind("gb", 0)
      {"gb", "region"}
      iex> LangTags.all("script") |> List.keyfind("en", 0)
      nil

  """
  @spec all(String.t()) :: [{String.t(), String.t()}]
  def all(type) when type in ["language", "extlang", "script", "region", "variant"] do
    Enum.filter(Registry.subtag_keys(), fn {_code, subtag_type} -> subtag_type == type end)
  end

  @doc """
  Returns the file date for the underlying data, as a string.

  ## Examples

      iex> LangTags.date() |> String.match?(~r/\\d{4}-\\d{2}-\\d{2}/)
      true

  """
  @spec date() :: String.t()
  def date, do: Registry.date()
end
