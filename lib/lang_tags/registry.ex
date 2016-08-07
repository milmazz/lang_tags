defmodule LangTags.Registry do
  def get_data(path) do
    :lang_tags
    |> Application.app_dir(path)
    |> File.read!()
    |> Poison.Parser.parse!
  end

  :lang_tags
  |> Application.app_dir("priv/language-subtag-registry/data/json/index.json")
  |> File.read!()
  |> Poison.Parser.parse!
  |> Enum.each(fn({k, v}) ->
    def index(unquote(k)) do
      unquote(Macro.escape(v))
    end
  end)

  def index(_), do: nil
end
