defmodule OpenAPI.TestSupport do
  @moduledoc false

  alias OpenAPI.Call
  alias OpenAPI.Processor
  alias OpenAPI.Reader
  alias OpenAPI.State

  @spec fixture_path(String.t()) :: String.t()
  def fixture_path(filename) do
    Path.expand("../fixture/#{filename}", __DIR__)
  end

  @spec with_profile(Keyword.t(), (atom -> term)) :: term
  def with_profile(config \\ [], fun) when is_list(config) and is_function(fun, 1) do
    profile = unique_profile()
    Application.put_env(:oapi_generator, profile, config)

    try do
      fun.(profile)
    after
      Application.delete_env(:oapi_generator, profile)
    end
  end

  @spec read!(atom, [String.t()]) :: OpenAPI.State.t()
  def read!(profile, files) when is_atom(profile) and is_list(files) do
    profile
    |> Atom.to_string()
    |> Call.new(files)
    |> State.new()
    |> Reader.run()
  end

  @spec process!(atom, [String.t()]) :: OpenAPI.State.t()
  def process!(profile, files) when is_atom(profile) and is_list(files) do
    profile
    |> Atom.to_string()
    |> Call.new(files)
    |> State.new()
    |> Reader.run()
    |> Processor.run()
  end

  @spec run!(atom, [String.t()]) :: OpenAPI.State.t()
  def run!(profile, files) when is_atom(profile) and is_list(files) do
    OpenAPI.run(Atom.to_string(profile), files)
  end

  @spec with_temp_dir(String.t(), (String.t() -> term)) :: term
  def with_temp_dir(prefix \\ "open-api-generator-test", fun)
      when is_binary(prefix) and is_function(fun, 1) do
    dir = Path.join(System.tmp_dir!(), "#{prefix}-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)

    try do
      fun.(dir)
    after
      File.rm_rf!(dir)
    end
  end

  @spec with_temp_spec(String.t(), (String.t(), String.t() -> term), Keyword.t()) :: term
  def with_temp_spec(contents, fun, opts \\ [])
      when is_binary(contents) and is_function(fun, 2) and is_list(opts) do
    extension = Keyword.get(opts, :extension, "yaml")

    with_temp_dir("open-api-generator-spec", fn dir ->
      spec_file = Path.join(dir, "spec.#{extension}")
      File.write!(spec_file, contents)
      fun.(spec_file, dir)
    end)
  end

  defp unique_profile do
    :"open_api_test_#{System.unique_integer([:positive])}"
  end
end
