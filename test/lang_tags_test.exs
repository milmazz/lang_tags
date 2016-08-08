defmodule LangTagsTest do
  use ExUnit.Case
  doctest LangTags

  alias LangTags, as: L

  test "date/0 returns file date" do
    assert L.date() == ~r/\d{4}-\d{2}-\d{2}/
  end

  test "type/2 returns subtag by type" do
    subtag = "Latn" |> L.type("script")

    assert subtag |> L.format() == "Latn"
    assert subtag |> L.type() == "script"

    refute L.type("en", "script")
  end

  test "region/1 returns subtag by region" do
    subtag = "IQ" |> L.region()

    assert subtag |> L.format() == "IQ"
    assert subtag |> L.type() == "region"

    refute L.region("en")
  end

  test "language/1 returns subtag by language" do
    subtag = "en" |> L.language()

    assert subtag |> L.format() == "en"
    assert subtag |> L.type() == "language"

    assert L.language("GB")
  end

  test "languages/1 returns all languages for macrolanguage" do
    subtags = "zh" |> L.languages()
    assert subtags |> Enum.count() > 0

    # try {
    #   assert tags.languages("en"))
    # } catch (e) {
    #   err = e
    # }

    # assert(err)
    # assert err.message, "\"en\" is not a macrolanguage.")
  end

  test "search/1 matches descriptions" do
    subtags = L.search("Maltese")
    assert subtags |> Enum.count() > 0

    assert subtags |> List.first() |> L.type() == "language"
    assert subtags |> List.first() |> L.format() == "mt"
    assert subtags |> Enum.at(1) |> L.type() == "language"
    assert subtags |> Enum.at(1) |> L.format() == "mdl"
    assert subtags |> Enum.at(2) |> L.type() == "extlang"
    assert subtags |> Enum.at(2) |> L.format() == "mdl"

    subtags = L.search("Gibberish")
    assert subtags == []
  end

  test "search/1 puts exact match at the top" do
    subtags = L.search("Dari")
    assert subtags |> Enum.count() > 0

    assert subtags |> List.first() |> L.type() == "language"
    assert subtags |> List.first() |> L.format() == "prs"
    end

  test "subtags/1 returns subtags" do
    subtags = "whatever" |>  L.subtags()
    assert subtags == []

    subtags = L.subtags("mt")
    assert subtags |> Enum.count() == 2
    assert subtags |> List.first() |> L.type() == "language"
    assert subtags |> List.first() |> L.format() == "mt"
    assert subtags |> Enum.at(1) |> L.type() == "region"
    assert subtags |> Enum.at(1) |> L.format() == "MT"
  end

  test "check/1 checks tag validity" do
    assert L.check("en")
    refute L.check("mo")
  end

#  test "gets tag" do
#    tag = tags("en")
#
#    tag = tags("en-gb")
#    assert tag |> L.format() == "en-GB"
#  end
end
