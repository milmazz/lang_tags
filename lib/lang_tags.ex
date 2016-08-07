defmodule LangTags do


  meta = LangTags.Registry.get_data("priv/language-subtag-registry/data/json/meta.json")

  def version do
    unquote(meta["File-Date"])
  end
end
