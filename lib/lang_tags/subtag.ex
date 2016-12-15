defmodule LangTags.SubTag do
  @moduledoc """
  Sub-tags
  """

  alias LangTags.Registry

  @doc """
  Creates a new subtag as a map
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
  Get the subtag type

  See [RFC 5646 section 2.2](http://tools.ietf.org/html/rfc5646#section-2.2) for
  type definitions.
  """
  @spec type(map) :: String.t | nil
  def type(subtag), do: subtag["Record"]["Type"]

  @doc """
  Returns the list of description strings (a subtag may have more than one description)

  ## Examples

    iex> LangTags.SubTag.new("ro", "language") |> LangTags.SubTag.descriptions()
    ["Romanian", "Moldavian", "Moldovan"]

  """
  @spec descriptions(map) :: String.t | nil
  def descriptions(subtag), do: subtag["Record"]["Description"]

  @doc """
  Returns a preferred subtag as a map if the subtag is deprecated.

  ## Examples

    # `ro` is preferred over deprecated `mo`.
    iex> LangTags.SubTag.new("mo", "language") |> LangTags.SubTag.preferred()
    %{"Record" => %{"Added" => "2005-10-16",
    "Description" => ["Romanian", "Moldavian", "Moldovan"], "Subtag" => "ro",
    "Suppress-Script" => "Latn", "Type" => "language"}, "Subtag" => "ro"}

  """
  @spec preferred(map) :: map | nil
  def preferred(subtag) do
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
  """
  @spec script(map) :: map | nil
  def script(subtag) do
    script = subtag["Record"]["Suppress-Script"]

    if script, do: new(script, "script"), else: nil
  end

  @doc """
  Returns the subtag scope as a string, or `nil` if the subtag has no scope.

    ## Examples

    iex> LangTags.SubTag.new("zh", "language") |> LangTags.SubTag.scope()
    "macrolanguage"
    iex> LangTags.SubTag.new("nah", "language") |> LangTags.SubTag.scope()
    "collection"

  """
  @spec scope(map) :: String.t | nil
  def scope(subtag), do: subtag["Record"]["Scope"]

  @doc """
  Returns a date string reflecting the deprecation date if the subtag is deprecated, otherwise returns `nil`.

  ## Examples

    iex> LangTags.SubTag.new("in", "language") |> LangTags.SubTag.deprecated()
    "1989-01-01"

  """
  @spec deprecated(map) :: String.t | nil
  def deprecated(subtag), do: subtag["Record"]["Deprecated"]

  @doc """
  Returns a date string reflecting the date the subtag was added to the registry.

  ## Examples

    iex> LangTags.SubTag.new("ja", "language") |> LangTags.SubTag.added()
    "2005-10-16"

  """
  @spec added(map) :: String.t | nil
  def added(subtag), do: subtag["Record"]["Added"]

  @doc """
  Returns an list of comments, if any, otherwise returns an empty list.

  ## Examples

    iex> LangTags.SubTag.new("nmf", "language") |> LangTags.SubTag.comments()
    ["see ntx"]

  """
  @spec comments(map) :: [String.t] | []
  def comments(subtag), do: subtag["Record"]["Comments"] || []

  @doc """
  Return the subtag code formatted according to the case conventions defined in [RFC 5646 section 2.1.1](http://tools.ietf.org/html/rfc5646#section-2.1.1).


    * language codes are made lowercase, for example: `mn` for Mongolian
    * script codes are made lowercase with the initial letter capitalized, for example: `Cyrl` for Cyrillic
    * country codes are capitalized, for example: `MN` for Mongolia

  ## Examples

    iex> LangTags.SubTag.new("mn", "language") |> LangTags.SubTag.format()
    "mn"
    iex> LangTags.SubTag.new("cyrl", "script") |> LangTags.SubTag.format()
    "Cyrl"
    iex> LangTags.SubTag.new("mn", "region") |> LangTags.SubTag.format()
    "MN"

  """
  @spec format(map) :: String.t
  def format(subtag) do
    process_format(subtag["Subtag"], subtag["Record"]["Type"])
  end

  defp process_format(subtag, type) when type == "region", do: String.upcase(subtag)
  defp process_format(subtag, type) when type == "script" do
    {char, rest} = String.Casing.titlecase_once(subtag)
    char <> rest
  end
  defp process_format(subtag, _), do: subtag
end
