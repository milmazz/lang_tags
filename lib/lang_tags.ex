defmodule LangTags do
  @moduledoc """
  Language Tags
  """

  alias LangTags.{Registry,Tag}

  def tags(tag), do: Tag.new(tag)

  def check(tag), do: Tag.valid(tag)

  def types(subtag) do
    type_info = Registry.types()[subtag]

    if type_info do
      Enum.filter(type_info, fn type -> type != "grandfathered" && type != "redundant" end)
    else
      []
    end
  end

  def subtags(_subtags) do
    # TODO: Implement
  end

  def filter(_subtags) do
    # TODO: Implement
  end

  def search(_query, _all) do
    # TODO: Implement
  end

  def languages(_macrolanguage) do
    # TODO: Implement
  end

  def language(subtag), do: type(subtag, "language")

  def region(subtag), do: type(subtag, "region")

  def type(subtag, type) do
    subtag = String.downcase(subtag)
    Tag.find_subtag(subtag, type)
  end

  def date, do: Registry.date()
end
