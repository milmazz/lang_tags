# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v0.2.1 - 2026-08-11

A performance release. No behaviour changes.

### Changed

  * The registry now compiles into lookup tables rather than one function
    clause per record. Generating 9203 `subtag/2` clauses and 8919 `types/1`
    clauses, each carrying its own map literal, accounted for about 16.6 of
    the module's 16.7 seconds. **Compiling the project now takes about 1.5
    seconds instead of about 16.6.** Lookups remain constant time on a term
    embedded in the compiled module, so nothing is parsed, copied or
    supervised at runtime.

### Fixed

  * `LangTags.Tag.new/1` and `LangTags.SubTag.find/2` used exceptions for
    control flow on their most common paths. `new/1` raised and rescued for
    every tag that is neither grandfathered nor redundant, which is almost
    every tag, and `find/2` raised whenever a code was not of the type being
    probed, which happens several times per tag. Raising cost about 44us
    against roughly 1us for the lookup itself. Both now use new non-raising
    lookups on the internal registry module, which return a tagged tuple
    rather than raising when a record is absent.
    **`Tag.valid?/1` went from about 174us to about 2.5us.** The public
    behaviour of both functions is unchanged.

## v0.2.0 - 2026-08-11

Published to [Hex](https://hex.pm/packages/lang_tags) on 2026-08-11.

The first release since v0.1.0 on 2016-12-19. It refreshes a decade of
registry data, repairs tag validation, and brings the project back onto a
supported toolchain.

### Registry data

The bundled IANA language subtag registry moved from **2016-10-12** to
**2026-08-08**, growing from 9001 to 9296 records.

This is the change most likely to affect you. Anyone on v0.1.0 has been
resolving language tags against data from 2016, so subtags added since then
were reported as unregistered and subtags deprecated since then were reported
as current.

Two consequences worth calling out, both upstream corrections rather than
changes in this library:

  * Descriptions have changed. For example Klingon's second description lost
    its hyphen, `"tlhIngan-Hol"` becoming `"tlhIngan Hol"`.
  * Tags that were valid in 2016 may no longer be. For example
    `hy-Latn-IT-arevela`, an example tag from RFC 5646 itself, is now invalid
    because the `arevela` variant was deprecated in 2018 in favour of `hy`.

### Added

  * `mix lang_tags.update` fetches the current registry from IANA and writes
    it to `priv/`. It validates the download before replacing the bundled
    copy, so an error page or a truncated body cannot clobber it. Pass
    `--check` to report whether an update is available without writing; it
    exits non-zero when one is, so it can drive a scheduled job. It uses
    OTP's own HTTP client and adds no dependency.
  * `LangTags.search/2` searches tag and subtag descriptions. It accepts a
    string, matched case-insensitively against any part of a description, or
    a `Regex`. Exact description matches are returned first and the rest
    follow in registry order. Grandfathered and redundant tags are excluded
    unless the `all` argument is `true`. The function had been present but
    commented out since 2016.
  * `LangTags.Tag.errors/1` is now documented public API with a `@spec` and a
    `@type`. It reports every reason a tag is invalid rather than stopping at
    the first.
  * Continuous integration on GitHub Actions, covering Elixir 1.15 through
    1.20 and OTP 26 through 29, with formatting, unused-dependency and Credo
    checks.
  * A `.formatter.exs`, and a `.git-blame-ignore-revs` so the commit that
    first applied it does not obscure `git blame`.

### Changed

  * Requires Elixir ~> 1.15.
  * `LangTags.Tag.errors/1` returns a list of maps shaped
    `%{code: atom, subtag: String.t(), message: String.t()}` instead of a list
    of strings such as `"ERR_DEPRECATED"`. Callers learn which subtag failed
    rather than only that something did. See the documentation for the full
    list of codes.
  * The application spec no longer lists `:logger`. The library uses it
    nowhere and starts no processes, so consumers building for production get
    an empty spec.
  * The package now declares its license using the SPDX identifier
    `Apache-2.0`.

### Fixed

  * `LangTags.Tag.valid?/1` returned the wrong answer and crashed on invalid
    input. The condition that added the "no language" error fired when the
    first subtag *was* a language, so `valid?("en")` returned `false`, and a
    tag whose subtags could not be resolved raised `FunctionClauseError`
    instead of returning `false`. Both were reachable through
    `LangTags.check/1`. Validation is now implemented against
    [RFC 5646 section 2.2.9](https://tools.ietf.org/html/rfc5646#section-2.2.9)
    and additionally checks for duplicate subtag types, canonical subtag
    order, and deprecated subtags, none of which were checked before.
  * Formatting a script or four-letter subtag raised `UndefinedFunctionError`
    on any recent Elixir. The library called `String.Casing.titlecase_once/1`,
    a private Elixir internal that has since been removed. It now uses
    `String.capitalize/1`, which also handles mixed-case input correctly:
    `"az-LATN"` now formats as `"az-Latn"` rather than `"az-LATN"`.

### Removed

  * The `config/` directory. It configured nothing, and configuration in a
    dependency is not loaded by the parent project anyway.
  * `.travis.yml`, replaced by GitHub Actions.
  * The `earmark` dependency, which is retired on Hex. ExDoc bundles its own
    markdown parser.

## v0.1.0 - 2016-12-19

Initial release.
