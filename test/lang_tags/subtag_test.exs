defmodule LangTags.SubTagTest do
  use ExUnit.Case
  doctest LangTags.SubTag

  alias LangTags.SubTag, as: ST

  test "SubTag.type() returns type" do
    assert ST.new("zh", "language") |> ST.type() == "language"
    assert ST.new("IQ", "region") |> ST.type() == "region"
  end

  test "SubTag.descriptions() returns descriptions" do
    assert ST.new("IQ", "region") |> ST.descriptions() == ["Iraq"]
    assert ST.new("vsv", "extlang") |> ST.descriptions() == ["Valencian Sign Language", "Llengua de signes valenciana"]
  end

  test "SubTag.preferred() returns preferred subtag" do
    # Extlang
    subtag = ST.new("vsv", "extlang")
    preferred = ST.preferred(subtag)
    assert preferred
    assert ST.type(preferred) == "language"
    assert ST.format(preferred) == "vsv"

    # Language
    # Moldovan -> Romanian
    subtag = ST.new("mo", "language")
    preferred = ST.preferred(subtag)
    assert preferred
    assert ST.type(preferred) == "language"
    assert ST.format(preferred) == "ro"

    # Region
    # Burma -> Myanmar
    subtag = ST.new("BU", "region")
    preferred = ST.preferred(subtag)
    assert preferred
    assert ST.type(preferred) == "region"
    assert ST.format(preferred) == "MM"

    # Variant
    subtag = ST.new("heploc", "variant")
    preferred = ST.preferred(subtag)
    assert preferred
    assert ST.type(preferred) == "variant"
    assert ST.format(preferred) == "alalc97"

    # Should return nil if no preferred value.
    # Latin America and the Caribbean
    subtag = ST.new("419", "region");
    assert ST.preferred(subtag) == nil
  end

  test "SubTag.script() returns suppress-script as subtag" do
    subtag = ST.new("en", "language")
    script = ST.script(subtag)
    assert script
    assert ST.type(script) == "script"
    assert ST.format(script) == "Latn"

    # Should return null if no script.
    # A macrolanguage like 'zh' should have no suppress-script.
    subtag = ST.new("zh", "language")
    script = ST.script(subtag)
    assert script == nil
  end

  test "SubTag.scope() returns scope" do
    assert ST.new("zh", "language") |> ST.scope() == "macrolanguage"
    assert ST.new("nah", "language") |> ST.scope() == "collection"
    assert ST.new("en", "language") |> ST.scope() == nil
    assert ST.new("IQ", "region") |> ST.scope() == nil
  end

  test "SubTag.deprecated() returns deprecation date if available" do
    # German democratic Republic
    assert ST.new("DD", "region") |> ST.deprecated() == "1990-10-30"
    assert ST.new("DE", "region") |> ST.deprecated() == nil
  end

  test "SubTag.added() returns date added" do
    assert ST.new("DD", "region") |> ST.added() == "2005-10-16"
    assert ST.new("DG", "region") |> ST.added() == "2009-07-29"
  end

  test "SubTag.comments() returns comments" do
    # Yugoslavia
    assert ST.new("YU", "region") |> ST.comments() == ["see BA, HR, ME, MK, RS, or SI"]
  end

  test "SubTag.format() formats subtag according to conventions" do
    # Language
    assert ST.new("en", "language") |> ST.format() == "en"
    assert ST.new("EN", "language") |> ST.format() == "en"

    # Region
    assert ST.new("GB", "region") |> ST.format() == "GB"
    assert ST.new("gb", "region") |> ST.format() == "GB"

    # Script
    assert ST.new("Latn", "script") |> ST.format() == "Latn"
    assert ST.new("latn", "script") |> ST.format() == "Latn"
  end
end
