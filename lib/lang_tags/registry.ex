defmodule LangTags.Registry do
  @moduledoc false

  # For more information about the Registry format, please see:
  # https://tools.ietf.org/html/rfc5646#section-3.1

  # Source:
  # http://www.iana.org/assignments/language-subtag-registry/language-subtag-registry
  @external_resource path = Application.app_dir(:lang_tags, "priv/language-subtag-registry")
  pattern = :binary.compile_pattern(": ")

  registry = String.split(File.read!(path) <> "%%", ~r{\r?\n})

  {_record, lang_types, subtag_records, tag_records, scope_records, macrolanguages} =
    Enum.reduce(registry, {%{}, %{}, [], [], %{}, %{}}, fn line,
                                                           {record, lang_types, subtag_records, tag_records,
                                                            scope_records, macrolanguages} ->
      case line |> String.trim() |> :binary.split(pattern) do
        # Records are separated by lines containing only the sequence "%%" (record-jar)
        ["%%"] ->
          # There are three types of records in the registry: "File-Date", "Subtag", and "Tag".
          {lang_types, subtag_records, tag_records, scope_records, macrolanguages} =
            case record do
              %{"Subtag" => subtag, "Type" => type} = record ->
                new_scope =
                  if type in ["language", "extlang"] && record["Scope"] do
                    Map.update(scope_records, record["Scope"], [subtag], &[subtag | &1])
                  else
                    scope_records
                  end

                macrolanguages =
                  if record["Macrolanguage"] do
                    Map.update(
                      macrolanguages,
                      record["Macrolanguage"],
                      [{subtag, type}],
                      &[{subtag, type} | &1]
                    )
                  else
                    macrolanguages
                  end

                lang_types =
                  Map.update(lang_types, subtag, MapSet.new([type]), &MapSet.put(&1, type))

                {lang_types, [record | subtag_records], tag_records, new_scope, macrolanguages}

              %{"Tag" => tag, "Type" => type} = record ->
                lang_types =
                  Map.update(lang_types, tag, MapSet.new([type]), &MapSet.put(&1, type))

                {lang_types, subtag_records, [record | tag_records], scope_records, macrolanguages}

              %{"File-Date" => file_date} ->
                def date do
                  unquote(file_date)
                end

                {lang_types, subtag_records, tag_records, scope_records, macrolanguages}
            end

          {%{}, lang_types, subtag_records, tag_records, scope_records, macrolanguages}

        ["Tag", v] ->
          # Lowercase for consistency (case is only a formatting convention, not a standard requirement).
          {Map.put(record, "Tag", String.downcase(v)), lang_types, subtag_records, tag_records, scope_records,
           macrolanguages}

        ["Subtag", v] ->
          # Lowercase for consistency (case is only a formatting convention, not a standard requirement).
          {Map.put(record, "Subtag", String.downcase(v)), lang_types, subtag_records, tag_records, scope_records,
           macrolanguages}

        ["Type", v] ->
          # Lowercase for consistency (case is only a formatting convention, not a standard requirement).
          {Map.put(record, "Type", String.downcase(v)), lang_types, subtag_records, tag_records, scope_records,
           macrolanguages}

        ["Comments", v] ->
          {Map.put(record, "Comments", [v]), lang_types, subtag_records, tag_records, scope_records, macrolanguages}

        ["Description", v] ->
          {Map.update(record, "Description", [v], &(&1 ++ [v])), lang_types, subtag_records, tag_records, scope_records,
           macrolanguages}

        [k, v] ->
          {Map.put(record, k, v), lang_types, subtag_records, tag_records, scope_records, macrolanguages}

        [comment] ->
          {Map.update(record, "Comments", [comment], &(&1 ++ [comment])), lang_types, subtag_records, tag_records,
           scope_records, macrolanguages}
      end
    end)

  # The tables below are built once at compile time and embedded as literals.
  #
  # Generating one function clause per record instead is roughly 165x slower to
  # compile: 9203 subtag/2 clauses and 8919 types/1 clauses accounted for about
  # 16.6 of the module's 16.7 seconds. Lookups stay a constant-time map access
  # on a term that lives in the module's literal pool, so nothing is parsed,
  # copied or supervised at runtime.
  #
  # Each attribute below is read from exactly one function, and it must stay
  # that way. A module attribute is inlined wherever it is mentioned, and the
  # literal pool does not fold the copies back together: measured on @subtags,
  # a second reference adds about 160 KB to the compiled module and around a
  # second of compile time, a third adds as much again. Anything that needs
  # these tables should call the wrapper function rather than name the
  # attribute a second time.

  ## Macrolanguages
  @macrolanguages Map.new(macrolanguages)

  @spec macrolanguages(String.t()) :: [{String.t(), String.t()}] | []
  def macrolanguages(macrolanguage), do: Map.get(@macrolanguages, macrolanguage, [])

  ## Types
  @types Map.new(lang_types, fn {key, available} -> {key, MapSet.to_list(available)} end)

  @spec types(String.t()) :: [String.t()] | []
  def types(subtag), do: Map.get(@types, subtag, [])

  @spec language?(String.t()) :: boolean
  def language?(subtag), do: "language" in types(String.downcase(subtag))

  @spec extlang?(String.t()) :: boolean
  def extlang?(subtag), do: "extlang" in types(String.downcase(subtag))

  @spec script?(String.t()) :: boolean
  def script?(subtag), do: "script" in types(String.downcase(subtag))

  @spec region?(String.t()) :: boolean
  def region?(subtag), do: "region" in types(String.downcase(subtag))

  @spec variant?(String.t()) :: boolean
  def variant?(subtag), do: "variant" in types(String.downcase(subtag))

  @spec grandfathered?(String.t()) :: boolean
  def grandfathered?(tag), do: "grandfathered" in types(String.downcase(tag))

  @spec redundant?(String.t()) :: boolean
  def redundant?(tag), do: "redundant" in types(String.downcase(tag))

  ## Subtags
  subtags =
    Map.new(subtag_records, fn %{"Subtag" => key, "Type" => type} = record ->
      {{key, type}, record}
    end)

  # The generated-clause version failed loudly on a duplicate {Subtag, Type}
  # record: the second clause was unreachable, which --warnings-as-errors made
  # fatal. Map.new/2 keeps whichever record comes last and says nothing, so a
  # registry refresh that introduced a duplicate would silently drop data.
  # Compare against the record count to keep the failure loud.
  if map_size(subtags) != length(subtag_records) do
    raise "priv/language-subtag-registry contains duplicate {Subtag, Type} records"
  end

  @subtags subtags

  @doc """
  Looks up a subtag record without raising when it is absent.

  Callers on a hot path should prefer this to `subtag/2`: a miss is an ordinary
  result here, and raising to signal one costs around 44us.
  """
  @spec fetch_subtag(String.t(), String.t()) :: {:ok, map} | :error
  def fetch_subtag(subtag, type), do: Map.fetch(@subtags, {subtag, type})

  @spec subtag(String.t(), String.t()) :: map
  def subtag(subtag, type) do
    case fetch_subtag(subtag, type) do
      {:ok, record} -> record
      :error -> raise_missing_subtag(subtag, type)
    end
  end

  defp raise_missing_subtag(subtag, type) when type in ["language", "extlang", "script", "region", "variant"] do
    raise(ArgumentError, "non-existent subtag '#{subtag}' of type '#{type}'.")
  end

  defp raise_missing_subtag(_subtag, type) when type in ["grandfathered", "redundant"] do
    raise(
      ArgumentError,
      ~S{invalid type for subtag, expected: "language", "extlang", "script", "region" or "variant"}
    )
  end

  defp raise_missing_subtag(subtag, _type) do
    raise(ArgumentError, "non-existent subtag '#{subtag}'.")
  end

  ## Tags
  tags = Map.new(tag_records, fn %{"Tag" => key} = record -> {key, record} end)

  # Same duplicate guard as @subtags above.
  if map_size(tags) != length(tag_records) do
    raise "priv/language-subtag-registry contains duplicate Tag records"
  end

  @tags tags

  @doc """
  Looks up a tag record without raising when it is absent.

  Most tags are neither grandfathered nor redundant, so a miss is the common
  case rather than an exceptional one.
  """
  @spec fetch_tag(String.t()) :: {:ok, map} | :error
  def fetch_tag(tag), do: Map.fetch(@tags, tag)

  @spec tag(String.t()) :: map
  def tag(tag) do
    case fetch_tag(tag) do
      {:ok, record} -> record
      :error -> raise(ArgumentError, "non-existent tag '#{tag}'.")
    end
  end

  ## Index
  #
  # Records are accumulated by prepending, so they are reversed here to restore
  # the order they appear in the registry file. Only the keys are stored: the
  # records themselves already live in the @subtags and @tags literals behind
  # fetch_subtag/2 and fetch_tag/1, and duplicating their descriptions would
  # roughly double the module's literals.
  @subtag_keys subtag_records
               |> Enum.reverse()
               |> Enum.map(fn %{"Subtag" => key, "Type" => type} -> {key, type} end)

  @tag_keys tag_records |> Enum.reverse() |> Enum.map(fn %{"Tag" => key} -> key end)

  @doc false
  @spec subtag_keys() :: [{String.t(), String.t()}]
  def subtag_keys, do: @subtag_keys

  @doc false
  @spec tag_keys() :: [String.t()]
  def tag_keys, do: @tag_keys

  ## Scopes
  @collections MapSet.new(scope_records["collection"] || [])
  @macrolanguage_scopes MapSet.new(scope_records["macrolanguage"] || [])
  @specials MapSet.new(scope_records["special"] || [])
  @private_uses MapSet.new(scope_records["private-use"] || [])

  @spec collection?(String.t()) :: boolean
  def collection?(subtag), do: MapSet.member?(@collections, subtag)

  @spec macrolanguage?(String.t()) :: boolean
  def macrolanguage?(subtag), do: MapSet.member?(@macrolanguage_scopes, subtag)

  @spec special?(String.t()) :: boolean
  def special?(subtag), do: MapSet.member?(@specials, subtag)

  @spec private_use?(String.t()) :: boolean
  def private_use?(subtag), do: MapSet.member?(@private_uses, subtag)
end
