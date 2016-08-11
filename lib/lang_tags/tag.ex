defmodule LangTags.Tag do
  @moduledoc """
  Tag
  """

  alias LangTags.Registry
  alias LangTags.SubTag

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

  def preferred(tag) do
    preferred = tag["Record"]["Preferred-Value"]

    if preferred, do: new(preferred), else: nil
  end

  def subtags(tag), do: process_subtags(tag, tag["Record"]["Type"])

  # No subtags if the tag is grandfathered
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

  def language(tag), do: find(tag, "language")

  def region(tag), do: find(tag, "region")

  def script(tag), do: find(tag, "script")

  def find(tag, filter), do: Enum.find(subtags(tag), &(type(&1) == filter))

  def valid(tag) do
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

  def type(tag), do: tag["Record"]["Type"] || "tag"

  def added(tag), do: tag["Record"]["Added"]

  def deprecated(tag), do: tag["Record"]["Deprecated"]

  def descriptions(tag), do: tag["Record"]["Description"] || []

  def format(tag) do
    # Format according to algorithm defined in RFC 5646 section 2.1.1.
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
