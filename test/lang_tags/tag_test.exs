defmodule LangTags.TagTest do
  use ExUnit.Case, async: true

  import LangTags.Tag,
    only: [
      added: 1,
      deprecated: 1,
      descriptions: 1,
      format: 1,
      language: 1,
      new: 1,
      preferred: 1,
      region: 1,
      subtags: 1,
      type: 1,
      valid?: 1
    ]

  alias LangTags.SubTag, as: ST
  alias LangTags.Tag

  doctest Tag

  test "extensions/1 groups each singleton with the subtags that follow it" do
    assert Tag.extensions("en-u-ca-buddhist-t-en") == %{"u" => ["ca", "buddhist"], "t" => ["en"]}
  end

  test "extensions/1 returns an empty map for a tag without extensions" do
    assert Tag.extensions("en-US") == %{}
  end

  test "extensions/1 excludes the private-use sequence" do
    # 'x' introduces private use, not an extension. See RFC 5646 section 2.2.7.
    assert Tag.extensions("en-u-ca-buddhist-x-priv") == %{"u" => ["ca", "buddhist"]}
    assert Tag.extensions("en-x-priv") == %{}
  end

  test "extensions/1 returns an empty map for grandfathered tags" do
    # 'i-klingon' opens with a singleton, but it is registered whole and so has
    # no extension sequence to report.
    assert Tag.extensions("i-klingon") == %{}
  end

  test "extensions/1 accepts a tag map as well as a string" do
    assert "en-u-ca-buddhist" |> new() |> Tag.extensions() == %{"u" => ["ca", "buddhist"]}
  end

  test "private_use/1 returns the subtags following the 'x' singleton" do
    assert Tag.private_use("en-x-priv-more") == ["priv", "more"]
  end

  test "private_use/1 returns an empty list when the tag has no private-use sequence" do
    assert Tag.private_use("en-US") == []
    assert Tag.private_use("en-u-ca-buddhist") == []
  end

  test "private_use/1 reads a tag that is wholly private use" do
    assert Tag.private_use("x-local") == ["local"]
  end

  test "private_use/1 returns an empty list for grandfathered tags" do
    assert Tag.private_use("i-klingon") == []
  end

  test "private_use/1 lowercases the sequence and accepts a tag map" do
    assert Tag.private_use("en-X-Priv") == ["priv"]
    assert "en-x-priv" |> new() |> Tag.private_use() == ["priv"]
  end

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
    assert Enum.count(subtags) == 1
    assert subtags |> List.first() |> ST.type() == "language"
    assert subtags |> List.first() |> ST.format() == "en"

    # Lowercase - lookup should be case insensitive.
    subtags = "en-mt" |> new() |> subtags()
    assert Enum.count(subtags) == 2
    assert subtags |> List.first() |> ST.type() == "language"
    assert subtags |> List.first() |> ST.format() == "en"
    assert subtags |> Enum.at(1) |> ST.type() == "region"
    assert subtags |> Enum.at(1) |> ST.format() == "MT"

    subtags = "en-mt-arab" |> new() |> subtags()
    assert Enum.count(subtags) == 3
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
    assert Enum.count(subtags) == 1
    assert subtags |> List.first() |> ST.type() == "language"
    assert subtags |> List.first() |> ST.format() == "en"
  end

  test "subtags/1 handles private tags" do
    subtags = "en-GB-x-Beano" |> new() |> subtags()
    assert Enum.count(subtags) == 2
    assert subtags |> List.first() |> ST.type() == "language"
    assert subtags |> List.first() |> ST.format() == "en"
    assert subtags |> List.last() |> ST.type() == "region"
    assert subtags |> List.last() |> ST.format() == "GB"
  end

  test "subtags/1 returns empty array for grandfathered tag" do
    tag = new("en-GB-oed")
    assert type(tag) == "grandfathered"
    subtags = subtags(tag)
    assert subtags == []
    assert region(tag) == nil
    assert language(tag) == nil
  end

  test "subtags/1 returns array for redundant tag" do
    tag = new("az-Arab")
    assert type(tag) == "redundant"
    subtags = subtags(tag)
    assert Enum.count(subtags) == 2
    assert subtags |> List.first() |> ST.format() == "az"
    assert subtags |> List.last() |> ST.format() == "Arab"
  end

  test "valid?/1 returns true for valid tag" do
    assert "en" |> new() |> valid?()
    assert "en-GB" |> new() |> valid?()
    assert "gsw" |> new() |> valid?()
    assert "de-CH" |> new() |> valid?()
  end

  test "valid?/1 returns true for subtag followed by private tag" do
    assert "en-x-whatever" |> new() |> valid?()
  end

  test "valid?/1 returns true for non-deprecated grandfathered tag" do
    # Grandfathered but not deprecated, therefore valid.
    tag = new("i-default")
    assert type(tag) == "grandfathered"
    refute deprecated(tag)
    assert valid?(tag)
  end

  test "valid?/1 returns true for non-deprecated redundant tag" do
    # Redundant but not deprecated, therefore valid.
    tag = new("zh-Hans")
    assert type(tag) == "redundant"
    refute deprecated(tag)
    assert valid?(tag)

    tag = new("es-419")
    assert type(tag) == "redundant"
    refute deprecated(tag)
    assert valid?(tag)
  end

  test "valid?/1 returns false for non-existent tag" do
    refute "zzz" |> new() |> valid?()
    refute "zzz-Latn" |> new() |> valid?()
    refute "en-Lzzz" |> new() |> valid?()
  end

  test "valid?/1 returns false for deprecated grandfathered tag" do
    # Grandfathered and deprecated, therefore invalid.
    tag = new("art-lojban")
    assert type(tag) == "grandfathered"
    assert deprecated(tag)
    refute valid?(tag)
  end

  test "valid?/1 returns false for deprecated redundant tag" do
    # Redundant and deprecated, therefore invalid.
    tag = new("zh-cmn")
    assert type(tag) == "redundant"
    assert deprecated(tag)
    refute valid?(tag)
    tag = new("zh-cmn-Hans")
    assert type(tag) == "redundant"
    assert deprecated(tag)
    refute valid?(tag)
  end

  test "valid?/1 returns false if contains deprecated subtags" do
    # Moldovan (mo) is deprecated as a language.
    refute "mo" |> new() |> valid?()

    # Neutral Zone (NT) is deprecated as a region.
    refute "en-NT" |> new() |> valid?()
  end

  test "valid?/1 returns false for tag with redundant script subtag" do
    # Swiss German (gsw) has a suppress script of Latn.
    refute "gsw-Latn" |> new() |> valid?()
  end

  test "valid?/1 returns false if tag contains no language tag and is not grandfathered or redundant" do
    refute "IQ-Arab" |> new() |> valid?()
    refute "419" |> new() |> valid?()
  end

  test "valid?/1 returns false if language subtag is not front of tag" do
    refute "GB-en" |> new() |> valid?()
  end

  test "valid?/1 returns false if more than one language subtag appears" do
    refute "en-en" |> new() |> valid?()
    refute "ko-en" |> new() |> valid?()
  end

  test "valid?/1 returns false if more than one region subtag appears" do
    refute "en-001-gb" |> new() |> valid?()
    refute "gb-001" |> new() |> valid?()
  end

  test "valid?/1 returns false if more than one extlang subtag appears" do
    refute "en-asp-bog" |> new() |> valid?()
  end

  test "valid?/1 returns false if more than one script subtag appears" do
    refute "arb-Latn-Cyrl" |> new() |> valid?()
  end

  test "valid?/1 returns false if a duplicate variant subtag appears" do
    refute "ca-valencia-valencia" |> new() |> valid?()
  end

  test "valid?/1 returns false if private-use subtag contains more than 8 characters" do
    # i.e. more than 8 in each component, not in total.

    # Long in total, but every component is within the limit.
    assert "en-x-more-than-eight-chars" |> new() |> valid?()

    # A single component of 18 characters.
    refute "en-x-morethaneightchars" |> new() |> valid?()
  end

  test "valid?/1 returns false if script subtag is same as language suppress-script" do
    refute "en-Latn" |> new() |> valid?()
    refute "en-GB-Latn" |> new() |> valid?()
    refute "gsw-Latn" |> new() |> valid?()
  end

  test "deprecated/1 returns deprecation date when available" do
    # Redundant and deprecated.
    tag = new("zh-cmn-Hant")
    assert type(tag) == "redundant"
    assert deprecated(tag) == "2009-07-29"

    # Redundant but not deprecated.
    tag = new("zh-Hans")
    assert type(tag) == "redundant"
    refute deprecated(tag)

    # Grandfathered and deprecated.
    tag = new("zh-xiang")
    assert type(tag) == "grandfathered"
    assert deprecated(tag) == "2009-07-29"

    # Grandfathered but not deprecated.
    tag = new("i-default")
    assert type(tag) == "grandfathered"
    refute deprecated(tag)
  end

  test "added/1 returns add date when available" do
    # Redundant and deprecated.
    tag = new("zh-cmn-Hant")
    assert type(tag) == "redundant"
    assert added(tag) == "2005-07-15"

    # Redundant but not deprecated.
    tag = new("zh-Hans")
    assert type(tag) == "redundant"
    refute deprecated(tag)
    assert added(tag) == "2003-05-30"

    # Grandfathered and deprecated.
    tag = new("zh-xiang")
    assert type(tag) == "grandfathered"
    assert added(tag) == "1999-12-18"

    # Grandfathered but not deprecated.
    tag = new("i-default")
    assert type(tag) == "grandfathered"
    refute deprecated(tag)
    assert added(tag) == "1998-03-10"
  end

  test "descriptions/1 returns descriptions when available" do
    tag = new("i-default")
    assert type(tag) == "grandfathered"
    refute deprecated(tag)
    assert descriptions(tag) == ["Default Language"]

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
    tag = new("zh-cmn-Hant")

    assert type(tag) == "redundant"
    assert deprecated(tag)
    assert preferred(tag)
    assert tag |> preferred() |> format() == "cmn-Hant"

    refute "zh-Hans" |> new() |> preferred()
  end

  test "region/1 and language/1 return subtags for redundant tags" do
    tag = new("es-419")
    assert tag |> region() |> descriptions() == ["Latin America and the Caribbean"]
    assert tag |> language() |> descriptions() == ["Spanish", "Castilian"]

    tag = new("sgn-NL")
    assert tag |> region() |> descriptions() == ["Netherlands"]
    assert tag |> language() |> descriptions() == ["Sign languages"]
  end
end
