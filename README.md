# LangTags: IANA Language Tags for Elixir

[![CI](https://github.com/milmazz/lang_tags/actions/workflows/ci.yml/badge.svg)](https://github.com/milmazz/lang_tags/actions/workflows/ci.yml)
[![Hex.pm](https://img.shields.io/hexpm/v/lang_tags.svg)](https://hex.pm/packages/lang_tags)
[![Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/lang_tags)

Work with IANA language tags in Elixir, based on [BCP 47][] ([RFC 5646][]) and
the [IANA language subtag registry][Registry].

The registry is parsed at compile time into lookup tables embedded in the
compiled module, so a lookup is a constant-time map access on a term that is
already in memory: there is no runtime parsing, no ETS table, no process to
supervise, and **no runtime dependencies**.

## Installation

Add `lang_tags` to your dependencies in `mix.exs`:

```elixir
def deps do
  [{:lang_tags, "~> 0.3"}]
end
```

## Usage

Look up a subtag:

```elixir
iex> LangTags.language("en")
%{"Record" => %{"Added" => "2005-10-16", "Description" => ["English"],
    "Subtag" => "en", "Suppress-Script" => "Latn", "Type" => "language"},
  "Subtag" => "en"}
```

Resolve a deprecated or grandfathered tag to its preferred value:

```elixir
iex> LangTags.Tag.preferred("i-klingon")
%{"Tag" => "tlh"}
```

Format a tag according to the RFC 5646 case conventions:

```elixir
iex> "az-latn-az" |> LangTags.Tag.new() |> LangTags.Tag.format()
"az-Latn-AZ"
```

Validate a tag, and find out why it was rejected:

```elixir
iex> LangTags.Tag.valid?("en-GB")
true

iex> LangTags.Tag.valid?("gsw-Latn")
false

iex> LangTags.Tag.errors("gsw-Latn")
[%{code: :suppress_script, subtag: "latn",
   message: "the script subtag 'latn' is the default for language 'gsw' and should be omitted"}]
```

`errors/1` reports every problem it finds rather than stopping at the first,
so a caller can show them together. See the [documentation][Docs] for the full
list of codes.

Search tags and subtags by description, with exact matches first:

```elixir
iex> LangTags.search("Maltese") |> Enum.map(&LangTags.SubTag.format/1)
["mt", "mdl", "mdl"]
```

Check which types a string is registered as:

```elixir
iex> LangTags.types("xml")
["extlang", "language"]
```

Match the tags you have against the language ranges a client asked for, such
as those in an `Accept-Language` header ([RFC 4647][]). `lookup/2` picks the
single best tag, shortening the range until something matches:

```elixir
iex> LangTags.Match.lookup(["en-GB", "fr", "zh-Hant"], ["zh-Hant-CN", "en"])
"zh-Hant"

iex> LangTags.Match.lookup(["en-GB", "fr"], ["de"])
nil
```

`filter/2` keeps every tag a range covers instead of choosing one:

```elixir
iex> LangTags.Match.filter(["de-DE-1996", "de-Deva", "en-GB"], ["de-DE"])
["de-DE-1996"]
```

Report the date of the bundled registry:

```elixir
iex> LangTags.date()
"2026-08-08"
```

See the [documentation][Docs] for the full API.

## Relationship to localize and ex_cldr

[localize][] — and [ex_cldr][], the family it replaces — also parses RFC 5646
tags, so it is easy to confuse them with this library. They answer different
questions.

localize resolves a tag to a *locale it ships data for*: it normalizes the tag,
resolves it to a CLDR canonical form through likely-subtag resolution, and
gives you the data to format numbers, dates, units, plurals and territory names
for one of CLDR's ~766 locales. `Localize.validate_locale/1` answers "can I
localize with this?"

`lang_tags` validates a tag against the *IANA registry*: whether every subtag
is actually registered, whether the tag or one of its subtags is deprecated and
what its preferred value is, and whether it breaks a `Suppress-Script` or
variant prefix rule — with a code and a message for each problem it finds. The
two are not the same test: `bis`, `in` and `zh-cmn-Hant` all resolve to a
locale under localize, while `lang_tags` reports them as unregistered or
deprecated and hands you the replacement to store.

So the two compose: reject or repair the tag against the registry, then ask
localize for a locale.

<!-- The example below is compiled and run by test/lang_tags/localize_integration_test.exs. -->
<!-- Keep the composition markers in place so that stays true. -->
<!-- composition:start -->

```elixir
defmodule MyApp.Locale do
  @doc "Resolve an externally supplied language tag to a locale we can format with."
  def resolve(input) do
    tag = LangTags.Tag.new(input)

    case LangTags.Tag.errors(tag) do
      [] ->
        Localize.validate_locale(LangTags.Tag.format(tag))

      errors ->
        # A deprecated tag carries a modern replacement; anything else is
        # input we should not accept.
        case LangTags.Tag.preferred(tag) do
          nil -> {:error, errors}
          preferred -> Localize.validate_locale(LangTags.Tag.format(preferred))
        end
    end
  end
end
```

<!-- composition:end -->

```elixir
# Case-corrected, then resolved.
iex> MyApp.Locale.resolve("en-gb")
{:ok, Localize.LanguageTag.new!("en-GB")}

# Deprecated since 2009. Handing localize the preferred value "cmn-Hant"
# resolves to zh-Hant, where passing "zh-cmn-Hant" to localize directly leaves
# the legacy extlang form in place.
iex> MyApp.Locale.resolve("zh-cmn-Hant")
{:ok, Localize.LanguageTag.new!("zh-Hant")}

# Rejected, with a reason to show the caller.
iex> MyApp.Locale.resolve("en-Qqqq")
{:error, [%{code: :unknown, subtag: "qqqq", message: "'qqqq' is not registered"}]}
```

Reach for `lang_tags` alone when you accept, correct or store tags but never
localize — an `Accept-Language` header, an `xml:lang` attribute, a locale
column. Reach for localize alone when your locales are a fixed set you control.

Already on ex_cldr? The same split applies, with `Cldr.validate_locale/2` in
place of `Localize.validate_locale/1`. ex_cldr is superseded by localize; see
its documentation for the current support timeline.

## Updating the registry

The IANA registry changes over time. To refresh the bundled copy:

```console
$ mix lang_tags.update
$ mix compile --force
```

The recompile is required because the registry is baked in at build time.

Use `mix lang_tags.update --check` to report whether an update is available
without writing anything; it exits non-zero when one is, so it can drive a
scheduled job.

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## Javascript version

This project is an Elixir version of the [language-tags][] Javascript project.

## License

Apache License 2.0. See [LICENSE][].

[BCP 47]: https://tools.ietf.org/html/bcp47
[RFC 5646]: https://tools.ietf.org/html/rfc5646
[RFC 4647]: https://tools.ietf.org/html/rfc4647
[Registry]: https://www.iana.org/assignments/language-subtag-registry
[Docs]: https://hexdocs.pm/lang_tags
[localize]: https://hex.pm/packages/localize
[ex_cldr]: https://hex.pm/packages/ex_cldr
[language-tags]: https://github.com/mattcg/language-tags
[LICENSE]: https://github.com/milmazz/lang_tags/blob/main/LICENSE
