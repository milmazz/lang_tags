defmodule LangTagsTest do
  use ExUnit.Case

  alias LangTags, as: L
  alias LangTags.SubTag, as: ST

  doctest L

  test "date/0 returns file date" do
    assert L.date() =~ ~r/\d{4}-\d{2}-\d{2}/
  end

  test "type/2 returns subtag by type" do
    subtag = L.type("Latn", "script")

    assert ST.format(subtag) == "Latn"
    assert ST.type(subtag) == "script"

    refute L.type("en", "script")
  end

  test "region/1 returns subtag by region" do
    subtag = L.region("IQ")

    assert ST.format(subtag) == "IQ"
    assert ST.type(subtag) == "region"

    refute L.region("en")
  end

  test "language/1 returns subtag by language" do
    subtag = L.language("en")

    assert ST.format(subtag) == "en"
    assert ST.type(subtag) == "language"

    refute L.language("GB")
  end

  test "languages/1 returns all languages for macrolanguage" do
    subtags = L.languages("zh")
    assert Enum.any?(subtags)

    assert_raise ArgumentError, ~r/is not a valid macrolanguage./, fn ->
      L.languages("en")
    end
  end

  test "search/1 matches descriptions" do
    subtags = L.search("Maltese")
    assert Enum.any?(subtags)

    assert subtags |> List.first() |> ST.type() == "language"
    assert subtags |> List.first() |> ST.format() == "mt"
    assert subtags |> Enum.at(1) |> ST.type() == "language"
    assert subtags |> Enum.at(1) |> ST.format() == "mdl"
    assert subtags |> Enum.at(2) |> ST.type() == "extlang"
    assert subtags |> Enum.at(2) |> ST.format() == "mdl"

    subtags = L.search("Gibberish")
    assert subtags == []
  end

  test "search/1 puts exact match at the top" do
    subtags = L.search("Dari")
    assert Enum.any?(subtags)

    assert subtags |> List.first() |> ST.type() == "language"
    assert subtags |> List.first() |> ST.format() == "prs"
  end

  test "subtags/1 returns subtags" do
    subtags = L.subtags("whatever")
    assert subtags == []

    subtags = L.subtags("mt")
    assert Enum.count(subtags) == 2
    assert subtags |> List.first() |> ST.type() == "language"
    assert subtags |> List.first() |> ST.format() == "mt"
    assert subtags |> Enum.at(1) |> ST.type() == "region"
    assert subtags |> Enum.at(1) |> ST.format() == "MT"
  end

  test "check/1 checks tag validity" do
    assert L.check("en")
    refute L.check("mo")
  end

  test "gets tag" do
    assert L.tags("en") == %{"Tag" => "en"}

    assert "en-gb" |> L.tags() |> LangTags.Tag.format() == "en-GB"
  end
end
