defmodule LangTags.MatchTest do
  use ExUnit.Case, async: true

  alias LangTags.Match

  doctest Match

  describe "filter/2" do
    test "matches a tag equal to the range" do
      assert Match.filter(["de", "en"], ["de"]) == ["de"]
    end

    test "matches a tag whose next character after the range is a hyphen" do
      assert Match.filter(["de-DE-1996"], ["de-de"]) == ["de-DE-1996"]
    end

    test "does not match a longer subtag that merely starts with the range" do
      # RFC 4647 section 3.3.1: "de-de" matches "de-DE-1996" but not "de-Deva"
      # or "de-Latn-DE". Comparing prefixes without requiring the hyphen would
      # wrongly match "de-Deva".
      assert Match.filter(["de-Deva", "de-Latn-DE"], ["de-de"]) == []
    end

    test "the wildcard range matches every tag" do
      assert Match.filter(["de", "en-GB"], ["*"]) == ["de", "en-GB"]
    end

    test "compares case-insensitively and returns the tag's own casing" do
      assert Match.filter(["en-GB"], ["EN-gb"]) == ["en-GB"]
    end

    test "returns matches in the order of the tags, not the ranges" do
      assert Match.filter(["fr", "en"], ["en", "fr"]) == ["fr", "en"]
    end

    test "returns a tag once even when several ranges match it" do
      assert Match.filter(["en-GB"], ["en", "en-GB"]) == ["en-GB"]
    end

    test "returns an empty list when nothing matches" do
      assert Match.filter(["fr"], ["de"]) == []
      assert Match.filter([], ["de"]) == []
      assert Match.filter(["fr"], []) == []
    end

    test "accepts a single range as a string" do
      assert Match.filter(["de-DE-1996", "fr"], "de") == ["de-DE-1996"]
    end
  end

  describe "lookup/2" do
    test "finds a tag equal to the range" do
      assert Match.lookup(["fr", "en"], ["en"]) == "en"
    end

    test "truncates the range until a tag matches" do
      assert Match.lookup(["en"], ["en-US"]) == "en"
      assert Match.lookup(["zh-Hant"], ["zh-Hant-CN"]) == "zh-Hant"
    end

    test "does not match a tag more specific than the range" do
      # Unlike filtering, lookup only ever shortens the range, so a range of
      # "en" never reaches "en-GB".
      assert Match.lookup(["en-GB"], ["en"]) == nil
    end

    test "removes a singleton together with its trailing subtag" do
      # RFC 4647 section 3.4 walks "zh-Hant-CN-x-private1-private2" down to
      # "zh-Hant-CN-x-private1" and then straight to "zh-Hant-CN", so the
      # intermediate "zh-Hant-CN-x" is never a candidate.
      assert Match.lookup(["zh-Hant-CN"], ["zh-Hant-CN-x-private1-private2"]) == "zh-Hant-CN"
      assert Match.lookup(["zh-Hant-CN-x"], ["zh-Hant-CN-x-private1"]) == nil
    end

    test "honours range priority over tag order" do
      assert Match.lookup(["fr", "en"], ["en", "fr"]) == "en"
      assert Match.lookup(["fr", "en"], ["de", "fr"]) == "fr"
    end

    test "returns the default when no range matches" do
      assert Match.lookup(["fr"], ["de"]) == nil
      assert Match.lookup([], ["de"]) == nil
      assert Match.lookup(["fr"], []) == nil
    end

    test "returns the default for a wildcard range" do
      # RFC 4647 section 3.4: '*' carries too little information for lookup,
      # so on its own it yields the default rather than an arbitrary tag.
      assert Match.lookup(["de", "fr"], ["*"]) == nil
    end

    test "skips a wildcard that is followed by another range" do
      assert Match.lookup(["de", "fr"], ["*", "fr"]) == "fr"
    end

    test "compares case-insensitively and returns the tag's own casing" do
      assert Match.lookup(["en-GB"], ["EN-gb"]) == "en-GB"
    end

    test "accepts a single range as a string" do
      assert Match.lookup(["en"], "en-US") == "en"
    end
  end
end
