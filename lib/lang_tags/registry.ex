defmodule LangTags.Registry do
  @moduledoc false

  # For more information about the Registry format, please see:
  # https://tools.ietf.org/html/rfc5646#section-3.1

  # Source:
  # http://www.iana.org/assignments/language-subtag-registry/language-subtag-registry
  @external_resource path = Application.app_dir(:lang_tags, "priv/language-subtag-registry")
  pattern = :binary.compile_pattern(": ")

  registry = String.split(File.read!(path) <> "%%", ~r{\r?\n})

  {_record, lang_types, subtag_records, tag_records, scope_records} =
    Enum.reduce registry, {%{}, %{}, [], [], %{}}, fn(line, {record, lang_types, subtag_records, tag_records, scope_records}) ->
      case line |> String.trim() |> :binary.split(pattern)  do
        # Records are separated by lines containing only the sequence "%%" (record-jar)
        ["%%"] ->
          # There are three types of records in the registry: "File-Date", "Subtag", and "Tag".
          {lang_types, subtag_records, tag_records, scope_records} =
            case record do
              %{"Subtag" => subtag, "Type" => type} = record ->
                new_scope =
                  if type in ["language", "extlang"] && record["Scope"] do
                    Map.update(scope_records, record["Scope"], [subtag], &([subtag | &1]))
                  else
                    scope_records
                  end
                lang_types = Map.update(lang_types, subtag, MapSet.new([type]), &(MapSet.put(&1, type)))
                {lang_types, [record | subtag_records], tag_records, new_scope}
              %{"Tag" => tag, "Type" => type} = record ->
                lang_types = Map.update(lang_types, tag, MapSet.new([type]), &(MapSet.put(&1, type)))
                {lang_types, subtag_records, [record | tag_records], scope_records}
              %{"File-Date" => file_date} ->
                def date() do
                  unquote(file_date)
                end
                {lang_types, subtag_records, tag_records, scope_records}
            end
          {%{}, lang_types, subtag_records, tag_records, scope_records}
        ["Tag", v] ->
          # Lowercase for consistency (case is only a formatting convention, not a standard requirement).
          {Map.put(record, "Tag", String.downcase(v)), lang_types, subtag_records, tag_records, scope_records}
        ["Subtag", v] ->
          # Lowercase for consistency (case is only a formatting convention, not a standard requirement).
          {Map.put(record, "Subtag", String.downcase(v)), lang_types, subtag_records, tag_records, scope_records}
        ["Type", v] ->
          # Lowercase for consistency (case is only a formatting convention, not a standard requirement).
          {Map.put(record, "Type", String.downcase(v)), lang_types, subtag_records, tag_records, scope_records}
        ["Comments", v] ->
          {Map.put(record, "Comments", [v]), lang_types, subtag_records, tag_records, scope_records}
        ["Description", v] ->
          {Map.update(record, "Description", [v], &(&1 ++ [v])), lang_types, subtag_records, tag_records, scope_records}
        [k, v] ->
          {Map.put(record, k, v), lang_types, subtag_records, tag_records, scope_records}
        [comment] ->
          {Map.update(record, "Comments", [comment], &(&1 ++ [comment])), lang_types, subtag_records, tag_records, scope_records}
      end
    end

  ## Types
  for {key, available_types} <- lang_types do
    def types(unquote(key)) do
      unquote(MapSet.to_list(available_types))
    end
  end

  def types(_), do: []

  ## Subtags
  for %{"Subtag" => key, "Type" => type} = subtag_record <- subtag_records do
    result = Macro.escape(subtag_record)

    def subtag(unquote(key), unquote(type)) do
      unquote(result)
    end
  end

  def subtag(subtag, type) when type in ["language", "extlang", "script", "region", "variant"] do
    raise "non-existent subtag '#{subtag}' of type '#{type}'."
  end

  def subtag(_subtag, type) when type in ["grandfathered", "redundant"] do
    raise ~S{invalid type for subtag, expected: "language", "extlang", "script", "region" or "variant"}
  end

  def subtag(subtag, _type) do
    raise "non-existent subtag '#{subtag}'."
  end

  ## Tags
  for %{"Tag" => key} = tag_record <- tag_records do
    result = Macro.escape(tag_record)

    def tag(unquote(key)) do
      unquote(result)
    end
  end

  def tag(tag) do
    raise "non-existent tag '#{tag}'."
  end

  ## Scopes
  for collection <- scope_records["collection"] do
    def collection?(unquote(collection)), do: true
  end

  def collection?(_), do: false

  for macrolanguage <- scope_records["macrolanguage"] do
    def macrolanguage?(unquote(macrolanguage)), do: true
  end

  def macrolanguage?(_), do: false

  for special <- scope_records["special"] do
    def special?(unquote(special)), do: true
  end

  def special?(_), do: false

  for private_use <- scope_records["private-use"] do
    def private_use?(unquote(private_use)), do: true
  end

  def private_use?(_), do: false
end
