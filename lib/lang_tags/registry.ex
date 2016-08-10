defmodule LangTags.Registry do
  path = Application.app_dir(:lang_tags, "priv/language-subtag-registry")

  {registry, tmp} = Enum.reduce File.stream!(path), {%{}, %{}}, fn(line, {acc, tmp}) ->
    # FIXME: What happens when a comment have at least one ':'?
    case line |> String.trim() |> String.split(": ", parts: 2)  do
      ["%%"] ->
        subtag = tmp["Subtag"] || tmp["Tag"]
        if subtag do
          type = tmp["Type"] |> String.downcase()

          entry = %{type => tmp}

          {Map.update(acc, subtag |> String.downcase(), entry, &Map.put(&1, type, tmp)), %{}}
        else
          {Map.merge(acc, tmp), %{}}
        end
      ["Comments", v] ->
        {acc, Map.put(tmp, "Comments", [v])}
      ["Description", v] ->
        {acc, Map.update(tmp, "Description", [v], &(&1 ++ [v]))}
      [k, v] ->
        {acc, Map.put(tmp, k, v)}
      [comment] ->
        {acc, Map.update(tmp, "Comments", [comment], &(&1 ++ [comment]))}
    end
  end

  registry =
    unless tmp == %{} do
      subtag = (tmp["Subtag"] || tmp["Tag"]) |> String.downcase()
      type = tmp["Type"] |> String.downcase()
      Map.update(registry, subtag |> String.downcase(), %{type => tmp}, &Map.put(&1, type, tmp))
    end

  def data() do
    unquote(Macro.escape(registry))
  end
end
