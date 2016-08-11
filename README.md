# LangTags: IANA Language Tags for Elixir

Based on [BCP 47][] ([RFC 5646][]) and the latest [IANA language subtag registry][Registry].

This project will be updated as the standards change.

## Installation

If [available in Hex][Hex], the package can be installed as:

  1. Add `lang_tags` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:lang_tags, "~> 0.1.0"}]
    end
    ```

  2. Ensure `lang_tags` is started before your application:

    ```elixir
    def application do
      [applications: [:lang_tags]]
    end
    ```

The docs can be found at [https://hexdocs.pm/lang_tags](https://hexdocs.pm/lang_tags)

[BCP 47]: http://tools.ietf.org/html/bcp47
[RFC 5646]: http://tools.ietf.org/html/rfc5646
[Registry]: http://www.iana.org/assignments/language-subtag-registry
[Hex]: https://hex.pm/docs/publish
