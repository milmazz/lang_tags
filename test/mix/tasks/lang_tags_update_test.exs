defmodule Mix.Tasks.LangTags.UpdateTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.LangTags.Update

  defp registry(records, file_date \\ "2026-08-08") do
    body =
      for i <- 1..records, into: "" do
        "Type: language\nSubtag: a#{i}\nDescription: Lang #{i}\nAdded: 2005-10-16\n%%\n"
      end

    "File-Date: #{file_date}\n%%\n" <> body
  end

  describe "parse_file_date/1" do
    test "returns the File-Date from registry contents" do
      assert Update.parse_file_date(registry(2)) == {:ok, "2026-08-08"}
    end

    test "returns :error when no File-Date header is present" do
      assert Update.parse_file_date("Type: language\nSubtag: aa\n") == :error
    end

    test "only accepts File-Date on the first line" do
      assert Update.parse_file_date("Type: language\nFile-Date: 2026-08-08\n") == :error
    end

    test "handles CRLF line endings" do
      assert Update.parse_file_date("File-Date: 2026-08-08\r\n%%\r\n") == {:ok, "2026-08-08"}
    end

    test "handles a header with no trailing newline" do
      assert Update.parse_file_date("File-Date: 2026-08-08") == {:ok, "2026-08-08"}
    end
  end

  describe "validate_registry/1" do
    test "accepts a well-formed registry" do
      assert Update.validate_registry(registry(2_000)) == :ok
    end

    test "rejects an HTML error page served instead of the registry" do
      html = "<!DOCTYPE html>\n<html><body>503 Service Unavailable</body></html>"

      assert {:error, message} = Update.validate_registry(html)
      assert message =~ "File-Date"
    end

    test "rejects a truncated download that lost most of its records" do
      assert {:error, message} = Update.validate_registry(registry(3))
      assert message =~ "too few records"
    end

    test "reports how many records it actually found when rejecting" do
      assert {:error, message} = Update.validate_registry(registry(3))
      assert message =~ "too few records (3)"
    end

    test "accepts a registry that uses CRLF line endings" do
      crlf = String.replace(registry(2_000), "\n", "\r\n")

      assert Update.validate_registry(crlf) == :ok
    end

    test "rejects empty contents" do
      assert {:error, _} = Update.validate_registry("")
    end
  end

  describe "file_date/1" do
    @describetag :tmp_dir

    test "reads the File-Date of a registry on disk", %{tmp_dir: dir} do
      path = Path.join(dir, "registry")
      File.write!(path, registry(500))

      assert Update.file_date(path) == {:ok, "2026-08-08"}
    end

    test "returns :error when the first line is not a File-Date header", %{tmp_dir: dir} do
      path = Path.join(dir, "registry")
      File.write!(path, "Type: language\nFile-Date: 2026-08-08\n")

      assert Update.file_date(path) == :error
    end

    test "returns :error when the file is empty", %{tmp_dir: dir} do
      path = Path.join(dir, "registry")
      File.write!(path, "")

      assert Update.file_date(path) == :error
    end

    test "returns :error when the file does not exist", %{tmp_dir: dir} do
      assert Update.file_date(Path.join(dir, "nope")) == :error
    end
  end
end
