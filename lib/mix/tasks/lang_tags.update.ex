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
    # :binary.split/2 stops at the first line break. A Regex here would scan
    # the whole body, which matters because this is handed the entire
    # multi-hundred-kilobyte download.
    [date | _] = :binary.split(rest, ["\r\n", "\n"])
    {:ok, String.trim(date)}
  end

  def parse_file_date(_contents), do: :error

  @doc """
  Reads the `File-Date` header of a registry file on disk.

  Only the first line is read. The registry is several hundred kilobytes and
  the header is its first line, so there is no reason to load the rest of it
  just to compare dates.
  """
  @spec file_date(Path.t()) :: {:ok, binary} | :error
  def file_date(path) do
    case File.open(path, [:read], &IO.read(&1, :line)) do
      {:ok, line} when is_binary(line) -> parse_file_date(line)
      _otherwise -> :error
    end
  end

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
        case count_records(contents, @min_records) do
          count when count >= @min_records ->
            :ok

          count ->
            {:error, "too few records (#{count}), expected at least #{@min_records}"}
        end
    end
  end

  # Records are separated by lines containing only "%%", with one extra
  # separator between the File-Date header and the first record.
  #
  # Validation only asks whether the floor is cleared, so stop counting there
  # instead of walking all ~9000 records. A body that falls short never
  # reaches the limit, so the exact count is still available for the error
  # message. Splitting lazily also avoids materialising ~49_000 line binaries.
  defp count_records(contents, limit) do
    contents
    |> String.splitter(["\r\n", "\n"])
    |> Enum.count_until(&(&1 == "%%"), limit + 1)
    |> Kernel.-(1)
    |> max(0)
  end

  defp current_file_date do
    case file_date(@registry_path) do
      {:ok, date} -> date
      :error -> nil
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

    # Identify the tool rather than issuing an anonymous request.
    headers = [{~c"user-agent", ~c"lang_tags (Elixir; +https://github.com/milmazz/lang_tags)"}]
    request = {String.to_charlist(url), headers}

    case :httpc.request(:get, request, http_opts, body_format: :binary) do
      {:ok, {{_version, 200, _reason}, _headers, body}} ->
        body

      {:ok, {{_version, status, reason}, _headers, _body}} when status in [403, 429] ->
        Mix.raise(
          "Failed to fetch registry: HTTP #{status} #{reason}. " <>
            "IANA throttles repeated requests, so this is usually transient. " <>
            "Wait a few minutes and try again."
        )

      {:ok, {{_version, status, reason}, _headers, _body}} ->
        Mix.raise("Failed to fetch registry: HTTP #{status} #{reason}")

      {:error, reason} ->
        Mix.raise("Failed to fetch registry: #{inspect(reason)}")
    end
  end
end
