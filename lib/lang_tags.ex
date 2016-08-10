defmodule LangTags do
  alias LangTags.Registry

  def date do
    registry = Registry.data()
    registry["File-Date"]
  end
end
