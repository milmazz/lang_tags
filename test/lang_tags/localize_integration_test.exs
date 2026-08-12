# Checks the claims the README makes about composing this library with
# localize, so that a change in either library shows up as a test failure
# rather than as quietly wrong documentation.
#
# localize is a test-only dependency and requires Elixir ~> 1.17, while this
# library supports ~> 1.15. On older versions the dependency is not declared
# (see mix.exs) and this module is never defined.
if Code.ensure_loaded?(Localize) do
  readme = Path.expand("../../README.md", __DIR__)

  # Compile the example out of the README itself. Copying it here would let the
  # two drift apart, which is the failure this file exists to catch. The markers
  # delimit the block so that renaming the module or reshaping the example does
  # not break extraction.
  start_marker = "<!-- composition:start -->"
  end_marker = "<!-- composition:end -->"

  snippet =
    with [_before, rest] <- String.split(File.read!(readme), start_marker, parts: 2),
         [block, _after] <- String.split(rest, end_marker, parts: 2) do
      block
      |> String.trim()
      |> String.trim_leading("```elixir")
      |> String.trim_trailing("```")
      |> String.trim()
    else
      _ ->
        raise """
        Could not find the composition example in README.md. Expected it between \
        `#{start_marker}` and `#{end_marker}`. Restore those markers around the \
        example, or update this test to match the README.
        """
    end

  Code.eval_string(snippet)

  defmodule LangTags.LocalizeIntegrationTest do
    use ExUnit.Case, async: true

    alias LangTags.Tag

    describe "the MyApp.Locale example compiled from README.md" do
      test "case-corrects a valid tag before resolving it" do
        assert {:ok, locale} = MyApp.Locale.resolve("en-gb")
        assert locale.canonical_locale_id == "en-GB"
      end

      test "upgrades a deprecated tag to its preferred value" do
        assert {:ok, locale} = MyApp.Locale.resolve("zh-cmn-Hant")
        assert locale.canonical_locale_id == "zh-Hant"
      end

      test "rejects an unregistered subtag with a reason to show the caller" do
        assert {:error, errors} = MyApp.Locale.resolve("en-Qqqq")

        assert errors == [
                 %{code: :unknown, subtag: "qqqq", message: "'qqqq' is not registered"}
               ]
      end
    end

    describe "the README claim that the two libraries apply different tests" do
      # "`bis`, `in` and `zh-cmn-Hant` all resolve to a locale under localize,
      # while `lang_tags` reports them as unregistered or deprecated and hands
      # you the replacement to store."
      test "localize resolves tags that the IANA registry rejects" do
        for tag <- ~w(bis in zh-cmn-Hant) do
          assert {:ok, _locale} = Localize.validate_locale(tag),
                 "expected localize to resolve #{tag}; the README says it does"

          refute Tag.valid?(tag),
                 "expected lang_tags to reject #{tag}; the README says it does"
        end
      end

      test "lang_tags explains each one as unregistered or deprecated" do
        assert [:unknown | _] = codes("bis")
        assert codes("in") == [:subtag_deprecated]
        assert codes("zh-cmn-Hant") == [:deprecated]
      end

      test "lang_tags supplies a replacement where the registry defines one" do
        assert "cmn-Hant" == "zh-cmn-Hant" |> Tag.preferred() |> Tag.format()
        assert "tlh" == "i-klingon" |> Tag.preferred() |> Tag.format()
      end
    end

    describe "the README claim that routing through lang_tags resolves better" do
      # "Handing localize the preferred value \"cmn-Hant\" resolves to zh-Hant,
      # where passing \"zh-cmn-Hant\" to localize directly leaves the legacy
      # extlang form in place."
      test "localize alone leaves the deprecated extlang form in place" do
        assert {:ok, direct} = Localize.validate_locale("zh-cmn-Hant")
        assert direct.canonical_locale_id == "zh-cmn-Hant"
      end

      test "the registry's preferred value resolves to a canonical locale" do
        preferred = "zh-cmn-Hant" |> Tag.preferred() |> Tag.format()

        assert {:ok, resolved} = Localize.validate_locale(preferred)
        assert resolved.canonical_locale_id == "zh-Hant"
      end
    end

    describe "the README's description of localize" do
      test "ships roughly the ~766 locales the README cites" do
        count = length(Localize.all_locale_ids())

        assert count in 700..850,
               "README cites ~766 CLDR locales but localize reports #{count}; " <>
                 "update the README if CLDR's coverage has moved"
      end

      test "validating a locale does not guarantee localize ships data for it" do
        # Why the README claims only that localize *resolves* these tags, and
        # never that it can format with them.
        assert {:ok, _} = Localize.validate_locale("tlh")
        refute Localize.available_locale_id?(:tlh)
      end
    end

    defp codes(tag), do: tag |> Tag.errors() |> Enum.map(& &1.code)
  end
end
