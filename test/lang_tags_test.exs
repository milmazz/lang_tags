defmodule LangTagsTest do
  use ExUnit.Case
  doctest LangTags

  alias LangTags, as: L
  alias LangTags.SubTag, as: ST

  test "date/0 returns file date" do
    assert L.date() =~ ~r/\d{4}-\d{2}-\d{2}/
  end

  test "type/2 returns subtag by type" do
    subtag = "Latn" |> L.type("script")

    assert subtag |> ST.format() == "Latn"
    assert subtag |> ST.type() == "script"

    refute L.type("en", "script")
  end

  test "region/1 returns subtag by region" do
    subtag = "IQ" |> L.region()

    assert subtag |> ST.format() == "IQ"
    assert subtag |> ST.type() == "region"

    refute L.region("en")
  end

  test "language/1 returns subtag by language" do
    subtag = "en" |> L.language()

    assert subtag |> ST.format() == "en"
    assert subtag |> ST.type() == "language"

    refute L.language("GB")
  end

  @tag :skip
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

  @tag :skip
  test "search/1 matches descriptions" do
    subtags = L.search("Maltese")
    assert subtags |> Enum.count() > 0

    assert subtags |> List.first() |> ST.type() == "language"
    assert subtags |> List.first() |> ST.format() == "mt"
    assert subtags |> Enum.at(1) |> ST.type() == "language"
    assert subtags |> Enum.at(1) |> ST.format() == "mdl"
    assert subtags |> Enum.at(2) |> ST.type() == "extlang"
    assert subtags |> Enum.at(2) |> ST.format() == "mdl"

    subtags = L.search("Gibberish")
    assert subtags == []
  end

  @tag :skip
  test "search/1 puts exact match at the top" do
    subtags = L.search("Dari")
    assert subtags |> Enum.count() > 0

    assert subtags |> List.first() |> ST.type() == "language"
    assert subtags |> List.first() |> ST.format() == "prs"
    end

  @tag :skip
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

  @tag :skip
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
