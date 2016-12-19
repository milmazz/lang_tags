defmodule LangTags.Mixfile do
  use Mix.Project

  @version "0.2.0-dev"

  def project do
    [app: :lang_tags,
     version: @version,
     description: "Work with IANA language tags in Elixir (BCP47 / RFC5646)",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     package: package()]
  end

  def application do
    [applications: [:logger]]
  end

  defp deps do
    [{:credo, "~> 0.4", only: :dev},
     {:ex_doc, "~> 0.14", only: :dev},
     {:earmark, "~> 1.0", only: :dev}]
  end

  defp package do
    [licenses: ["Apache 2.0"],
     maintainers: ["Milton Mazzarri"],
     links: %{"GitHub" => "https://github.com/milmazz/lang_tags"}]
  end
end
