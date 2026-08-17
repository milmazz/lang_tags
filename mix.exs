defmodule LangTags.Mixfile do
  use Mix.Project

  @version "0.3.1"
  @source_url "https://github.com/milmazz/lang_tags"

  def project do
    [
      app: :lang_tags,
      version: @version,
      description: "Work with IANA language tags in Elixir (BCP47 / RFC5646)",
      elixir: "~> 1.15",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs(),
      # mix lang_tags.update reaches into OTP's HTTP stack, but the library
      # itself needs nothing at runtime, so these stay out of the
      # application spec rather than being forced on every consumer.
      elixirc_options: [no_warn_undefined: [:httpc, :public_key]]
    ]
  end

  def application do
    [extra_applications: extra_applications(Mix.env())]
  end

  # The library starts no processes and needs nothing at runtime. OTP's HTTP
  # stack is required only by `mix lang_tags.update`, so it is declared for
  # dev and test alone: Mix prunes unused applications from the code path,
  # and without this the task cannot load :public_key. Consumers building for
  # prod get an empty application spec.
  defp extra_applications(env) when env in [:dev, :test], do: [:inets, :ssl, :public_key]
  defp extra_applications(_env), do: []

  defp deps do
    [
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false},
      {:styler, "~> 1.12", only: [:dev, :test], runtime: false}
    ] ++ localize_dep()
  end

  # The README documents how to compose this library with localize, and
  # test/lang_tags/localize_integration_test.exs checks that documentation
  # against the real thing. localize requires Elixir ~> 1.17 while this library
  # supports ~> 1.15, so the dependency is declared only where it can resolve;
  # the test module is skipped when it is absent.
  defp localize_dep do
    if Version.match?(System.version(), ">= 1.17.0") do
      [{:localize, "~> 1.1", only: :test}]
    else
      []
    end
  end

  defp package do
    [
      licenses: ["Apache-2.0"],
      maintainers: ["Milton Mazzarri"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib priv mix.exs README.md CHANGELOG.md LICENSE)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "CHANGELOG.md"],
      source_url: @source_url,
      source_ref: "v#{@version}"
    ]
  end
end
