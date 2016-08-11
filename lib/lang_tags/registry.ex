defmodule LangTags.Registry do
  @moduledoc false

  # For more information about the Registry format, please see:
  # https://tools.ietf.org/html/rfc5646#section-3.1

  # Source:
  # http://www.iana.org/assignments/language-subtag-registry/language-subtag-registry
  @external_resource path = Application.app_dir(:lang_tags, "priv/language-subtag-registry")
  pattern = :binary.compile_pattern(": ")

  {acc, lang_types} =
    Enum.reduce File.stream!(path), {%{}, %{}}, fn(line, {acc, lang_types}) ->
      case line |> String.trim() |> :binary.split(pattern)  do
        # Records are separated by lines containing only the sequence "%%" (record-jar)
        ["%%"] ->
          # There are three types of records in the registry: "File-Date", "Subtag", and "Tag".
          lang_types = case acc do
            # FIXME: This takes too long, is it normal in this case?
            %{"Subtag" => subtag, "Type" => type} = acc ->
              result = Macro.escape(acc)

              def subtag(unquote(subtag), unquote(type)) do
                unquote(result)
              end
              Map.update(lang_types, subtag, MapSet.new([type]), &(MapSet.put(&1, type)))
            %{"Tag" => tag, "Type" => type} = acc ->
              result = Macro.escape(acc)

              def tag(unquote(tag)) do
                unquote(result)
              end

              def tag(unquote(tag), unquote(type)) do
                unquote(result)
              end
              Map.update(lang_types, tag, MapSet.new([type]), &(MapSet.put(&1, type)))
            %{"File-Date" => file_date} ->
              def date() do
                unquote(file_date)
              end
              lang_types
          end
          {%{}, lang_types}
        ["Tag", v] ->
          # Lowercase for consistency (case is only a formatting convention, not a standard requirement).
          {Map.put(acc, "Tag", String.downcase(v)), lang_types}
        ["Subtag", v] ->
          # Lowercase for consistency (case is only a formatting convention, not a standard requirement).
          {Map.put(acc, "Subtag", String.downcase(v)), lang_types}
        ["Type", v] ->
          # Lowercase for consistency (case is only a formatting convention, not a standard requirement).
          {Map.put(acc, "Type", String.downcase(v)), lang_types}
        ["Comments", v] ->
          {Map.put(acc, "Comments", [v]), lang_types}
        ["Description", v] ->
          {Map.update(acc, "Description", [v], &(&1 ++ [v])), lang_types}
        [k, v] ->
          {Map.put(acc, k, v), lang_types}
        [comment] ->
          {Map.update(acc, "Comments", [comment], &(&1 ++ [comment])), lang_types}
      end
    end

  # FIXME: Last record (without '%%' at the end), duplicate code (DRY principle)
    if %{"Tag" => tag, "Type" => type} = acc do
      result = {:%{}, [], Map.to_list(acc)}

      def tag(unquote(tag)) do
        unquote(result)
      end

      def tag(unquote(tag), unquote(type)) do
        unquote(result)
      end

      all_types = lang_types |> Map.update(tag, MapSet.new([type]), &(MapSet.put(&1, type))) |> Macro.escape()

      def types() do
        unquote(all_types)
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

  def tag(tag, type) when type in ["grandfathered", "redundant"] do
    raise "non-existent tag '#{tag}' of type '#{type}'."
  end

  def tag(_tag, type) when type in ["language", "extlang", "script", "region", "variant"] do
    raise ~S{invalid type for tag, expected: "grandfathered" or "redundant"}
  end

  def tag(tag) do
    raise "non-existent tag '#{tag}'."
  end
end
