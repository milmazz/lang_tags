defmodule LangTags.TagTest do
  use ExUnit.Case, async: true
  doctest LangTags.Tag

  import LangTags.Tag, only: [added: 1, deprecated: 1, descriptions: 1,
                              format: 1, language: 1, new: 1, preferred: 1,
                              region: 1, subtags: 1, type: 1, valid?: 1]

  alias LangTags.SubTag, as: ST

  test "type/1 returns 'grandfathered'" do
    # Classified as grandfathered in the registry.
    assert "en-GB-oed" |> new() |> type() == "grandfathered"
  end

  test "type/1 returns 'redundant'" do
    # Classified as redundant in the registry.
    assert "az-Arab" |> new() |> type() == "redundant"
    assert "uz-Cyrl" |> new() |> type() == "redundant"
    assert "zh-cmn-Hant" |> new() |> type() == "redundant"
  end

  test "type/1 returns 'tag'" do
    # Maltese (mt) is a subtag but valid as a standalone tag.
    assert "mt" |> new() |> type() == "tag"
  end

  test "subtags/1 returns subtags with correct type" do
    subtags = "en" |> new() |> subtags()
    assert subtags |> Enum.count() == 1
    assert subtags |> List.first() |> ST.type() == "language"
    assert subtags |> List.first() |> ST.format() == "en"

    # Lowercase - lookup should be case insensitive.
    subtags = "en-mt" |> new() |> subtags()
    assert subtags |> Enum.count() == 2
    assert subtags |> List.first() |> ST.type() == "language"
    assert subtags |> List.first() |> ST.format() == "en"
    assert subtags |> Enum.at(1) |> ST.type() == "region"
    assert subtags |> Enum.at(1) |> ST.format() == "MT"

    subtags = "en-mt-arab" |> new() |> subtags()
    assert subtags |> Enum.count() == 3
    assert subtags |> Enum.at(0) |> ST.type() == "language"
    assert subtags |> Enum.at(0) |> ST.format() == "en"
    assert subtags |> Enum.at(1) |> ST.type() == "region"
    assert subtags |> Enum.at(1) |> ST.format() == "MT"
    assert subtags |> Enum.at(2) |> ST.type() == "script"
    assert subtags |> Enum.at(2) |> ST.format() == "Arab"
  end

  test "subtags/1 returns only existent subtags" do
    assert "hello" |> new() |> subtags() == []

    subtags = "en-hello" |> new() |> subtags()
    assert subtags |> Enum.count() == 1
    assert subtags |> List.first() |> ST.type() == "language"
    assert subtags |> List.first() |> ST.format() == "en"
  end

  test "subtags/1 handles private tags" do
    subtags = "en-GB-x-Beano" |> new() |> subtags()
    assert subtags |> Enum.count() == 2
    assert subtags |> List.first() |> ST.type() == "language"
    assert subtags |> List.first() |> ST.format() == "en"
    assert subtags |> List.last() |> ST.type() == "region"
    assert subtags |> List.last() |> ST.format() == "GB"
  end

  test "subtags/1 returns empty array for grandfathered tag" do
    tag = "en-GB-oed" |> new()
    assert tag |> type() == "grandfathered"
    subtags = tag |> subtags()
    assert subtags == []
    assert tag |> region() == nil
    assert tag |> language() == nil
  end

  test "subtags/1 returns array for redundant tag" do
    tag = "az-Arab" |> new()
    assert tag |> type() == "redundant"
    subtags = tag |> subtags()
    assert subtags |> Enum.count() == 2
    assert subtags |> List.first() |> ST.format() == "az"
    assert subtags |> List.last() |> ST.format() == "Arab"
  end

  @tag :skip
  test "valid?/1 returns true for valid tag" do
    assert "en" |> new() |> valid?()
    assert "en-GB" |> new() |> valid?()
    assert "gsw" |> new() |> valid?()
    assert "de-CH" |> new() |> valid?()
  end

  @tag :skip
  test "valid?/1 returns true for subtag followed by private tag" do
    assert "en-x-whatever" |> new() |> valid?()
  end

  @tag :skip
  test "valid?/1 returns true for non-deprecated grandfathered tag" do
    # Grandfathered but not deprecated, therefore valid.
    tag = "i-default" |> new()
    assert tag |> type() == "grandfathered"
    refute tag |> deprecated()
    assert tag |> valid?()
  end

  @tag :skip
  test "valid?/1 returns true for non-deprecated redundant tag" do
    # Redundant but not deprecated, therefore valid.
    tag = "zh-Hans" |> new()
    assert tag |> type() == "redundant"
    refute tag |> deprecated()
    assert tag |> valid?()

    tag = "es-419" |> new()
    assert tag |> type() == "redundant"
    refute tag |> deprecated()
    assert tag |> valid?()
  end

  @tag :skip
  test "valid?/1 returns false for non-existent tag" do
    refute "zzz" |> new |> valid?()
    refute "zzz-Latn" |> new() |> valid?()
    refute "en-Lzzz" |> new() |> valid?()
  end

  @tag :skip
  test "valid?/1 returns false for deprecated grandfathered tag" do
    # Grandfathered and deprecated, therefore invalid.
    tag = "art-lojban" |> new()
    assert tag |> type() == "grandfathered"
    assert tag |> deprecated()
    refute tag |> valid?()
  end

  @tag :skip
  test "valid?/1 returns false for deprecated redundant tag" do
    # Redundant and deprecated, therefore invalid.
    tag = "zh-cmn" |> new()
    assert tag |> type() == "redundant"
    assert tag |> deprecated()
    refute tag |> valid?()
    tag = "zh-cmn-Hans" |> new()
    assert tag |> type() == "redundant"
    assert tag |> deprecated()
    refute tag |> valid?()
  end

  @tag :skip
  test "valid?/1 returns false if contains deprecated subtags" do
    # Moldovan (mo) is deprecated as a language.
    refute "mo" |> new() |> valid?()

    # Neutral Zone (NT) is deprecated as a region.
    refute "en-NT" |> new() |> valid?()
  end

  @tag :skip
  test "valid?/1 returns false for tag with redundant script subtag" do
    # Swiss German (gsw) has a suppress script of Latn.
    refute "gsw-Latn" |> new() |> valid?()
  end

  @tag :skip
  test "valid?/1 returns false if tag contains no language tag and is not grandfathered or redundant" do
    refute "IQ-Arab" |> new() |> valid?()
    refute "419" |> new() |> valid?()
  end

  @tag :skip
  test "valid?/1 returns false if language subtag is not front of tag" do
    refute "GB-en" |> new() |> valid?()
  end

  @tag :skip
  test "valid?/1 returns false if more than one language subtag appears" do
    refute "en-en" |> new() |> valid?()
    refute "ko-en" |> new() |> valid?()
  end

  @tag :skip
  test "valid?/1 returns false if more than one region subtag appears" do
    refute "en-001-gb" |> new() |> valid?()
    refute "gb-001" |> new() |> valid?()
  end

  @tag :skip
  test "valid?/1 returns false if more than one extlang subtag appears" do
    refute "en-asp-bog" |> new() |> valid?()
  end

  @tag :skip
  test "valid?/1 returns false if more than one script subtag appears" do
    refute "arb-Latn-Cyrl" |> new() |> valid?()
  end

  @tag :skip
  test "valid?/1 returns false if a duplicate variant subtag appears" do
    refute "ca-valencia-valencia" |> new() |> valid?()
  end

  @tag :skip
  test "valid?/1 returns false if private-use subtag contains more than 8 characters" do
    # i.e. more than 8 in each component, not in total.
    refute "en-x-more-than-eight-chars" |> new() |> valid?()
    refute "en-x-morethaneightchars" |> new() |> valid?()
  end

  @tag :skip
  test "valid?/1 returns false if script subtag is same as language suppress-script" do
    "en-Latn" |> new() |> valid?()
    "en-GB-Latn" |> new() |> valid?()
    "gsw-Latn" |> new() |> valid?()
  end

  test "deprecated/1 returns deprecation date when available" do
    # Redundant and deprecated.
    tag = "zh-cmn-Hant" |> new()
    assert tag |> type() == "redundant"
    assert tag |> deprecated() == "2009-07-29"

    # Redundant but not deprecated.
    tag = "zh-Hans" |> new()
    assert tag |> type() == "redundant"
    refute tag |> deprecated()

    # Grandfathered and deprecated.
    tag = "zh-xiang" |> new()
    assert tag |> type() == "grandfathered"
    assert tag |> deprecated() == "2009-07-29"

    # Grandfathered but not deprecated.
    tag = "i-default" |> new()
    assert tag |> type() == "grandfathered"
    refute tag |> deprecated()
  end

  test "added/1 returns add date when available" do
    # Redundant and deprecated.
    tag = "zh-cmn-Hant" |> new()
    assert tag |> type() == "redundant"
    assert tag |> added() == "2005-07-15"

    # Redundant but not deprecated.
    tag = "zh-Hans" |> new()
    assert tag |> type() == "redundant"
    refute tag |> deprecated()
    assert tag |> added() == "2003-05-30"

    # Grandfathered and deprecated.
    tag = "zh-xiang" |> new()
    assert tag |> type() == "grandfathered"
    assert tag |> added() == "1999-12-18"

    # Grandfathered but not deprecated.
    tag = "i-default" |> new()
    assert tag |> type() == "grandfathered"
    refute tag |> deprecated()
    assert tag |> added() == "1998-03-10"
  end

  test "descriptions/1 returns descriptions when available" do
    tag = "i-default" |> new()
    assert tag |> type() == "grandfathered"
    refute tag |> deprecated()
    assert tag |> descriptions() == ["Default Language"]

    # Otherwise returns an empty array.
    assert "en" |> new() |> descriptions() == []
  end

  test "format/1 formats tag according to conventions" do
    assert "en" |> new() |> format() == "en"
    assert "En" |> new() |> format() == "en"
    assert "EN" |> new() |> format() == "en"
    assert "eN" |> new() |> format() == "en"
    assert "en-gb" |> new() |> format() == "en-GB"
    assert "en-gb-oed" |> new() |> format() == "en-GB-oed"
    assert "az-latn" |> new() |> format() == "az-Latn"
    assert "ZH-hant-hK" |> new() |> format() == "zh-Hant-HK"
  end

  test "preferred/1 returns preferred tag if available" do
    tag = "zh-cmn-Hant" |> new()

    assert tag |> type() == "redundant"
    assert tag |> deprecated()
    assert tag |> preferred()
    assert tag |> preferred() |> format() == "cmn-Hant"

    refute "zh-Hans" |> new() |> preferred()
  end

  test "region/1 and language/1 return subtags for redundant tags" do
    tag = "es-419" |> new()
    assert tag |> region() |> descriptions() == ["Latin America and the Caribbean"]
    assert tag |> language() |> descriptions() == ["Spanish", "Castilian"]

    tag = "sgn-NL" |> new()
    assert tag |> region() |> descriptions() == ["Netherlands"]
    assert tag |> language() |> descriptions() == ["Sign languages"]
  end
end
