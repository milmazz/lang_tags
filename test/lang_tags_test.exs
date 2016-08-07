defmodule LangTagsTest do
  use ExUnit.Case
  doctest LangTags

  test "version" do
    assert LangTags.version == "2016-06-30"
  end
end
