defmodule LangTags.SubTag do
  @moduledoc """
  Subtags according to the [BCP47](https://tools.ietf.org/html/bcp47)

  This module contains the subtags defined in the BCP47, the allowed *types*
  for a subtag are: "language", "extlang", "script", "region", or variant.
  """

  alias LangTags.Registry

  @doc """
  Creates a new subtag as a map

  ## Examples

      iex> LangTags.SubTag.new("es", "language")
      LangTags.SubTag.new("es", "language")
      iex> LangTags.SubTag.new("es", "script")
      ** (ArgumentError) non-existent subtag 'es' of type 'script'.

  """
  @spec new(String.t, String.t) :: map
  def new(subtag, type) do
    # Lowercase for consistency (case is only a formatting convention, not a
    # standard requirement).
    subtag = String.downcase(subtag)
    type = String.downcase(type)

    %{"Subtag" => subtag, "Record" => Registry.subtag(subtag, type)}
  end

  @doc """
  If found, returns a map for the given subtag, `nil` otherwise.

  ## Examples

      iex> LangTags.SubTag.find("tlh", "language")
      %{"Record" => %{"Added" => "2005-10-16",
          "Description" => ["Klingon", "tlhIngan-Hol"], "Subtag" => "tlh",
          "Type" => "language"}, "Subtag" => "tlh"}
      iex> LangTags.SubTag.find("ef", "script")
      nil

  """
  @spec find(String.t, String.t) :: map | nil
  def find(subtag, type) do
    try do
      new(subtag, type)
    rescue
      ArgumentError -> nil
    end
  end

  @doc """
  Get the subtag type

  See [RFC 5646 section 2.2](http://tools.ietf.org/html/rfc5646#section-2.2) for
  type definitions.

  ## Examples

      iex> LangTags.language("af") |> LangTags.SubTag.type() == "language"
      true

  """
  @spec type(map) :: String.t | nil
  def type(subtag) when is_map(subtag), do: subtag["Record"]["Type"]

  @doc """
  Returns `true` if subtag is of "language" type, `false` otherwise.

  ## Examples

      iex> LangTags.SubTag.language?("af")
      true

  """
  @spec language?(String.t) :: boolean
  def language?(subtag), do: Registry.language?(subtag)

  @doc """
  Returns `true` if subtag is of "extlang" type, `false` otherwise.

  ## Examples

      iex> LangTags.SubTag.extlang?("acm")
      true

  """
  @spec extlang?(String.t) :: boolean
  def extlang?(subtag), do: Registry.extlang?(subtag)

  @doc """
  Returns `true` if subtag is of "script" type, `false` otherwise.

  ## Examples

      iex> LangTags.SubTag.script?("aghb")
      true

  """
  @spec script?(String.t) :: boolean
  def script?(subtag), do: Registry.script?(subtag)

  @doc """
  Returns `true` if subtag is of "region" type, `false` otherwise.

  ## Examples

      iex> LangTags.SubTag.region?("ad")
      true
      iex> LangTags.SubTag.region?("en")
      false

  """
  @spec region?(String.t) :: boolean
  def region?(subtag), do: Registry.region?(subtag)

  @doc """
  Returns `true` if subtag is of "variant" type, `false` otherwise.

  ## Examples

      iex> LangTags.SubTag.variant?("1901")
      true

  """
  @spec variant?(String.t) :: boolean
  def variant?(subtag), do: Registry.variant?(subtag)

  @doc """
  Returns the list of description strings (a subtag may have more than one description)

  ## Examples

      iex> LangTags.language("ro") |> LangTags.SubTag.descriptions()
      ["Romanian", "Moldavian", "Moldovan"]

  """
  @spec descriptions(map) :: String.t | nil
  def descriptions(subtag) when is_map(subtag), do: subtag["Record"]["Description"]

  @doc """
  Returns a preferred subtag as a map if the subtag is deprecated.

  ## Examples

      # `ro` is preferred over deprecated `mo`.
      iex> LangTags.language("mo") |> LangTags.SubTag.preferred()
      %{"Record" => %{"Added" => "2005-10-16",
          "Description" => ["Romanian", "Moldavian", "Moldovan"], "Subtag" => "ro",
          "Suppress-Script" => "Latn", "Type" => "language"}, "Subtag" => "ro"}

  """
  @spec preferred(map) :: map | nil
  def preferred(subtag) when is_map(subtag) do
    process_preferred(subtag, subtag["Record"]["Preferred-Value"])
  end

  defp process_preferred(_subtag, nil), do: nil
  defp process_preferred(subtag, preferred) do
    type = if subtag["Record"]["Type"] == "extlang", do: "language", else: subtag["Record"]["Type"]
    new(preferred, type)
  end

  @doc """
  Returns a `Subtag` map representing the language's default script.

  For subtags of type *language* or *extlang*, returns a `Subtag` map
  representing the language's default script. See [RFC 5646 section 3.1.9](http://tools.ietf.org/html/rfc5646#section-3.1.9)
  for a definition of *Suppress-Script*.

  ## Examples

      iex> LangTags.language("af") |> LangTags.SubTag.script() == LangTags.SubTag.new("Latn", "script")
      true
      iex> LangTags.language("ae") |> LangTags.SubTag.script()
      nil

  """
  @spec script(map) :: map | nil
  def script(subtag) when is_map(subtag) do
    script = subtag["Record"]["Suppress-Script"]

    if script, do: new(script, "script"), else: nil
  end

  @doc """
  Returns the subtag scope as a string, or "individual" if the subtag has no scope.

  ## Examples

      iex> LangTags.language("zh") |> LangTags.SubTag.scope()
      "macrolanguage"
      iex> LangTags.language("nah") |> LangTags.SubTag.scope()
      "collection"

  """
  @spec scope(map) :: String.t
  def scope(subtag) when is_map(subtag), do: subtag["Record"]["Scope"] || "individual"

  @doc """
  Returns a date string reflecting the deprecation date if the subtag is deprecated, otherwise returns `nil`.

  ## Examples

      iex> LangTags.language("in") |> LangTags.SubTag.deprecated()
      "1989-01-01"

  """
  @spec deprecated(map) :: String.t | nil
  def deprecated(subtag) when is_map(subtag), do: subtag["Record"]["Deprecated"]

  @doc """
  Returns a date string reflecting the date the subtag was added to the registry.

  ## Examples

      iex> LangTags.language("ja") |> LangTags.SubTag.added()
      "2005-10-16"

  """
  @spec added(map) :: String.t | nil
  def added(subtag) when is_map(subtag), do: subtag["Record"]["Added"]

  @doc """
  Returns an list of comments, if any, otherwise returns an empty list.

  ## Examples

      iex> LangTags.language("nmf") |> LangTags.SubTag.comments()
      ["see ntx"]

  """
  @spec comments(map) :: [String.t] | []
  def comments(subtag) when is_map(subtag), do: subtag["Record"]["Comments"] || []

  @doc """
  Return the subtag code formatted according to the case conventions defined in [RFC 5646 section 2.1.1](http://tools.ietf.org/html/rfc5646#section-2.1.1).


    * language codes are made lowercase, for example: `mn` for Mongolian
    * script codes are made lowercase with the initial letter capitalized, for example: `Cyrl` for Cyrillic
    * country codes are capitalized, for example: `MN` for Mongolia

  ## Examples

      iex> LangTags.language("mn") |> LangTags.SubTag.format()
      "mn"
      iex> LangTags.script("cyrl") |> LangTags.SubTag.format()
      "Cyrl"
      iex> LangTags.region("mn") |> LangTags.SubTag.format()
      "MN"

  """
  @spec format(map) :: String.t
  def format(subtag) when is_map(subtag) do
    process_format(subtag["Subtag"], subtag["Record"]["Type"])
  end

  defp process_format(subtag, type) when type == "region", do: String.upcase(subtag)
  defp process_format(subtag, type) when type == "script" do
    {char, rest} = String.Casing.titlecase_once(subtag)
    char <> rest
  end
  defp process_format(subtag, _), do: subtag

  @doc """
  Indicates if the given string is a subtag that represents a collection of languages

  A collection is typically related by some type of historical, geographical,
  or linguistic association.

  Unlike a macrolanguage, a collection can contain languages that are only
  loosely related and a collection cannot be used interchangeably with languages
  that belong to it.

  ## Examples

      iex> LangTags.SubTag.collection?("cdd")
      true

  """
  @spec collection?(String.t) :: boolean
  def collection?(subtag) when is_binary(subtag), do: subtag |> String.downcase() |> Registry.collection?()

  @doc """
  Indicates if the given string is a macrolanguage as defined by ISO 639-3.

  A macrolanguage is a cluster of closely related languages that are sometimes
  considered to be a single language.

  ## Examples

      iex> LangTags.SubTag.macrolanguage?("kpe")
      true

  """
  @spec macrolanguage?(String.t) :: boolean
  def macrolanguage?(subtag) when is_binary(subtag), do: subtag |> String.downcase() |> Registry.macrolanguage?()

  @doc """
  Indicates if the given string represents a special language code.

  These are subtags used for identifying linguistic attributes not particularly
  associated with a concrete language. These include codes for when the language
  is undetermined or for non-linguistic content.

  ## Examples

      iex> LangTags.SubTag.special?("zxx")
      true

  """
  @spec special?(String.t) :: boolean
  def special?(subtag) when is_binary(subtag), do: subtag |> String.downcase() |> Registry.special?()

  @doc """
  Indicates if the given string represents a code reserved for private use in the ISO 639 standard.

  Subtags with this scope can be used to indicate a primary language for which
  no ISO 639 or registered assignment exists.

  ## Examples

      iex> LangTags.SubTag.private_use?("qaa..qtz")
      true

  """
  @spec private_use?(String.t) :: boolean
  def private_use?(subtag) when is_binary(subtag), do: subtag |> String.downcase() |> Registry.private_use?()
end
