# LangTags: IANA Language Tags for Elixir

[![CI](https://github.com/milmazz/lang_tags/actions/workflows/ci.yml/badge.svg)](https://github.com/milmazz/lang_tags/actions/workflows/ci.yml)
[![Hex.pm](https://img.shields.io/hexpm/v/lang_tags.svg)](https://hex.pm/packages/lang_tags)
[![Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/lang_tags)

Work with IANA language tags in Elixir, based on [BCP 47][] ([RFC 5646][]) and
the [IANA language subtag registry][Registry].

The registry is parsed at compile time into pattern-matched function heads, so
lookups are plain function dispatch: there is no runtime parsing, no ETS table,
no process to supervise, and **no runtime dependencies**.

## Installation

Add `lang_tags` to your dependencies in `mix.exs`:

```elixir
def deps do
  [{:lang_tags, "~> 0.2"}]
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

Report the date of the bundled registry:

```elixir
iex> LangTags.date()
"2026-08-08"
```

See the [documentation][Docs] for the full API.

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
[Registry]: https://www.iana.org/assignments/language-subtag-registry
[Docs]: https://hexdocs.pm/lang_tags
[language-tags]: https://github.com/mattcg/language-tags
[LICENSE]: https://github.com/milmazz/lang_tags/blob/master/LICENSE
