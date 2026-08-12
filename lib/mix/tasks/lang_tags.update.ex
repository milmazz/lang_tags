defmodule Mix.Tasks.LangTags.Update do
  @shortdoc "Updates the bundled IANA language subtag registry"

  @moduledoc """
  Fetches the current IANA language subtag registry and writes it to
  `priv/language-subtag-registry`.

      $ mix lang_tags.update

  The registry is compiled into pattern-matched function heads at build time,
  so a recompile is required for the new data to take effect:

      $ mix lang_tags.update
      $ mix compile --force

  ## Options

    * `--check` - report whether a newer registry is available without writing
      anything. Exits with a non-zero status when an update is available, which
      makes it usable as a scheduled CI check.

  """

  use Mix.Task

  @registry_url "https://www.iana.org/assignments/language-subtag-registry/language-subtag-registry"
  @registry_path "priv/language-subtag-registry"

  # The published registry carries thousands of records. Anything near-empty
  # means we were served a truncated body or an error page, and overwriting
  # the bundled copy with it would be destructive.
  @min_records 1_000

  @impl Mix.Task
  def run(argv) do
    {opts, _, _} = OptionParser.parse(argv, strict: [check: :boolean])

    Mix.shell().info("Fetching #{@registry_url}")
    contents = fetch!(@registry_url)

    case validate_registry(contents) do
      :ok -> :ok
      {:error, reason} -> Mix.raise("Refusing to write downloaded registry: #{reason}")
    end

    {:ok, new_date} = parse_file_date(contents)
    current = current_file_date() || "unknown"

    cond do
      current == new_date ->
        Mix.shell().info("Already up to date (File-Date: #{new_date})")

      opts[:check] ->
        Mix.shell().info("Update available: #{current} -> #{new_date}")
        exit({:shutdown, 1})

      true ->
        File.write!(@registry_path, contents)
        Mix.shell().info("Updated #{@registry_path}: #{current} -> #{new_date}")
        Mix.shell().info("Run `mix compile --force` to rebuild the compiled registry.")
    end
  end

  @doc """
  Extracts the `File-Date` header from registry contents.

  The header is only recognised on the first line, which is where the
  record-jar format requires it.
  """
  @spec parse_file_date(binary) :: {:ok, binary} | :error
  def parse_file_date("File-Date: " <> rest) do
    [date | _] = String.split(rest, ~r/\r?\n/, parts: 2)
    {:ok, String.trim(date)}
  end

  def parse_file_date(_contents), do: :error

  @doc """
  Checks that contents look like the IANA registry before we overwrite the
  bundled copy with them.
  """
  @spec validate_registry(binary) :: :ok | {:error, binary}
  def validate_registry(contents) do
    case parse_file_date(contents) do
      :error ->
        {:error, "response does not begin with a File-Date header (probably an error page)"}

      {:ok, _date} ->
        case count_records(contents) do
          count when count >= @min_records ->
            :ok

          count ->
            {:error, "too few records (#{count}), expected at least #{@min_records}"}
        end
    end
  end

  defp count_records(contents) do
    contents
    |> String.split(~r/\r?\n/)
    |> Enum.count(&(&1 == "%%"))
    |> Kernel.-(1)
    |> max(0)
  end

  defp current_file_date do
    with {:ok, contents} <- File.read(@registry_path),
         {:ok, date} <- parse_file_date(contents) do
      date
    else
      _ -> nil
    end
  end

  defp fetch!(url) do
    {:ok, _} = Application.ensure_all_started(:inets)
    {:ok, _} = Application.ensure_all_started(:ssl)

    http_opts = [
      ssl: [
        verify: :verify_peer,
        cacerts: :public_key.cacerts_get(),
        depth: 3,
        customize_hostname_check: [
          match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
        ]
      ],
      timeout: 60_000,
      connect_timeout: 30_000
    ]

    case :httpc.request(:get, {String.to_charlist(url), []}, http_opts, body_format: :binary) do
      {:ok, {{_version, 200, _reason}, _headers, body}} ->
        body

      {:ok, {{_version, status, reason}, _headers, _body}} ->
        Mix.raise("Failed to fetch registry: HTTP #{status} #{reason}")

      {:error, reason} ->
        Mix.raise("Failed to fetch registry: #{inspect(reason)}")
    end
  end
end
