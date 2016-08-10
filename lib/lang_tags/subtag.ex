defmodule LangTags.SubTag do
  alias LangTags.Registry

  def new(subtag, type) do
    registry = Registry.data()
    # Lowercase for consistency (case is only a formatting convention, not a standard requirement).
    subtag = String.downcase(subtag)
    type = String.downcase(type)

    types = registry[subtag]
    unless types do
      raise "Non-existent subtag '#{subtag}'."
    end

    record = types[type]
    unless record do
      raise "Non-existent subtag '#{subtag}' of type '#{type}'."
    end

    unless record["Subtag"] do
      raise "'#{subtag}' is a '#{type}' tag."
    end

    %{
      subtag: subtag,
      record: record,
      type: type
    }
  end

  def type(subtag) do
    subtag.type
  end

  def descriptions(subtag) do
    # Every record has one or more descriptions (stored as an array).
    subtag[:record]["Description"]
  end

  def preferred(subtag) do
    preferred = subtag[:record]["Preferred-Value"]

    if preferred do
      type = if subtag.type == "extlang", do: "language", else: subtag.type

      new(preferred, type)
    else
      nil
    end
  end

  def script(subtag) do
    script = subtag[:record]["Suppress-Script"]

    if script do
      new(script, "script")
    else
      nil
    end
  end

  def scope(subtag) do
    subtag[:record]["Scope"] || nil
  end

  def deprecated(subtag) do
    subtag[:record]["Deprecated"] || nil
  end

  def added(subtag) do
    subtag[:record]["Added"]
  end

  def comments(subtag) do
    # Comments don't always occur for records, so switch to an empty array if missing.
    subtag[:record]["Comments"] || []
  end

  def format(subtag) do
    sub_tag = subtag[:subtag]

    case subtag.type do
      "region" ->
        String.upcase(sub_tag)
      "script" ->
        {char, rest} = String.Casing.titlecase_once(sub_tag)
        char <> rest
      _ ->
        sub_tag
    end
  end
end
