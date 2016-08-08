defmodule LangTags.Tag do
  def new(tag) do
    # FIXME: This is inefficient.
    registry = LangTags.SubTag.registry()

    # Lowercase for consistency (case is only a formatting
    # convention, not a standard requirement)
    tag = tag |> String.trim() |> String.downcase()

    # Check if the input tag is grandfathered or redundant
    types = LangTags.Registry.index(tag)
    record =
      if types["grandfathered"] || types["redundant"] do
        # FIXME: This should be moved to LangTags.Registry
        Enum.at(registry, types["grandfathered"]) || Enum.at(registry, types["redundant"])
      else
        nil
      end

    %{tag: tag, record: record}
  end

  def preferred(tag) do
    preferred = tag["record"]["Preferred-Value"]

    if preferred do
      new(preferred)
    else
      nil
    end
  end

  def subtags(tag) do
    
  end

  def language(tag) do
    find(tag, "language")
  end

  def region(tag) do
    find(tag, "region")
  end

  def script(tag) do
    find(tag, "script")
  end

  def find(tag, filter) do
    for subtag <- tag.subtags() do
      if type(subtag) == filter do
        subtag
      end 
    end
  end

  def valid(tag) do
    
  end

  def type(tag) do
    if tag["record"]["Type"] do
      tag["record"]["Type"]
    else
      "tag"
    end
  end

  def added(tag) do
    tag["record"]["Added"]
  end

  def deprecated(tag) do
    tag["record"]["Deprecated"]
  end

  def descriptions(tag) do
    if tag["record"] do
      tag["record"]["Description"]
    else
      []
    end
  end

  def format(tag) do
    # Format according to algorithm defined in RFC 5646 section 2.1.1.
    tag.tag
    |> String.split("-")
    |> Enum.reduce(fn(x, acc) ->
        x
       end)
  end
end
