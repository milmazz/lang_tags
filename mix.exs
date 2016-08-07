defmodule LangTags.Mixfile do
  use Mix.Project

  def project do
    [app: :lang_tags,
     version: "0.1.0",
     elixir: "~> 1.4-dev",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  def application do
    [applications: [:logger]]
  end

  defp deps do
    [{:poison, "~> 2.0"},
     {:ex_doc, "~> 0.13", only: :dev},
     {:earmark, "~> 1.0", only: :dev}]
  end
end
