defmodule LangTags.SubTagTest do
  use ExUnit.Case, async: true

  import LangTags.SubTag,
    only: [
      added: 1,
      comments: 1,
      deprecated: 1,
      descriptions: 1,
      format: 1,
      new: 2,
      preferred: 1,
      scope: 1,
      script: 1,
      type: 1
    ]

  doctest LangTags.SubTag

  test "type/1 returns type" do
    assert "zh" |> new("language") |> type() == "language"
    assert "IQ" |> new("region") |> type() == "region"
  end

  test "descriptions/1 returns descriptions" do
    assert "IQ" |> new("region") |> descriptions() == ["Iraq"]

    assert "vsv" |> new("extlang") |> descriptions() == [
             "Valencian Sign Language",
             "Llengua de signes valenciana"
           ]
  end

  test "preferred/1 returns preferred subtag" do
    # Extlang
    subtag = new("vsv", "extlang")
    preferred = preferred(subtag)
    assert preferred
    assert type(preferred) == "language"
    assert format(preferred) == "vsv"

    # Language
    # Moldovan -> Romanian
    subtag = new("mo", "language")
    preferred = preferred(subtag)
    assert preferred
    assert type(preferred) == "language"
    assert format(preferred) == "ro"

    # Region
    # Burma -> Myanmar
    subtag = new("BU", "region")
    preferred = preferred(subtag)
    assert preferred
    assert type(preferred) == "region"
    assert format(preferred) == "MM"

    # Variant
    subtag = new("heploc", "variant")
    preferred = preferred(subtag)
    assert preferred
    assert type(preferred) == "variant"
    assert format(preferred) == "alalc97"

    # Should return nil if no preferred value.
    # Latin America and the Caribbean
    subtag = new("419", "region")
    refute preferred(subtag)
  end

  test "script/1 returns suppress-script as subtag" do
    subtag = new("en", "language")
    script = script(subtag)
    assert script
    assert type(script) == "script"
    assert format(script) == "Latn"

    # Should return nil if no script.
    # A macrolanguage like 'zh' should have no suppress-script.
    subtag = new("zh", "language")
    script = script(subtag)
    refute script
  end

  test "scope/1 returns scope" do
    assert "zh" |> new("language") |> scope() == "macrolanguage"
    assert "nah" |> new("language") |> scope() == "collection"
    assert "en" |> new("language") |> scope() == "individual"
    assert "IQ" |> new("region") |> scope() == "individual"
  end

  test "deprecated/1 returns deprecation date if available" do
    # German democratic Republic
    assert "DD" |> new("region") |> deprecated() == "1990-10-30"
    assert "DE" |> new("region") |> deprecated() == nil
  end

  test "added/1 returns date added" do
    assert "DD" |> new("region") |> added() == "2005-10-16"
    assert "DG" |> new("region") |> added() == "2009-07-29"
  end

  test "comments/1 returns comments" do
    # Yugoslavia
    assert "YU" |> new("region") |> comments() == ["see BA, HR, ME, MK, RS, or SI"]
  end

  test "format/1 formats subtag according to conventions" do
    # Language
    assert "en" |> new("language") |> format() == "en"
    assert "EN" |> new("language") |> format() == "en"

    # Region
    assert "GB" |> new("region") |> format() == "GB"
    assert "gb" |> new("region") |> format() == "GB"

    # Script
    assert "Latn" |> new("script") |> format() == "Latn"
    assert "latn" |> new("script") |> format() == "Latn"
  end
end
