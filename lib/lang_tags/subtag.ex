defmodule LangTags.SubTag do
  @moduledoc """
  Sub-tags
  """

  alias LangTags.Registry

  def new(subtag, type) do
    # Lowercase for consistency (case is only a formatting convention, not a standard requirement).
    subtag = String.downcase(subtag)
    type = String.downcase(type)

    %{"Subtag" => subtag, "Record" => Registry.subtag(subtag, type)}
  end

  def type(subtag), do: subtag["Record"]["Type"]

  # Every record has one or more descriptions (stored as an array).
  def descriptions(subtag), do: subtag["Record"]["Description"]

  def preferred(subtag) do
    preferred(subtag, subtag["Record"]["Preferred-Value"])
  end

  defp preferred(_subtag, nil), do: nil
  defp preferred(subtag, preferred) do
    type = if subtag["Record"]["Type"] == "extlang", do: "language", else: subtag["Record"]["Type"]
    new(preferred, type)
  end

  def script(subtag) do
    script = subtag["Record"]["Suppress-Script"]

    if script, do: new(script, "script"), else: nil
  end

  def scope(subtag), do: subtag["Record"]["Scope"]

  def deprecated(subtag), do: subtag["Record"]["Deprecated"]

  def added(subtag), do: subtag["Record"]["Added"]

  # Comments don't always occur for records, so switch to an empty array if missing.
  def comments(subtag), do: subtag["Record"]["Comments"] || []

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
