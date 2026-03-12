defmodule OpenAPIGenerationTest do
  use ExUnit.Case, async: false

  @profile :open_api_generation_test

  defmodule Client do
    @moduledoc false

    def request(payload), do: payload
  end

  @spec_json """
  {
    "openapi": "3.0.0",
    "info": {
      "title": "Name Override API",
      "version": "1.0.0"
    },
    "paths": {
      "/submit": {
        "post": {
          "summary": "Submit name with header override",
          "parameters": [
            {
              "name": "x-override-name",
              "in": "header",
              "required": true,
              "description": "Override the submitted name",
              "schema": {
                "type": "string"
              }
            },
            {
              "name": "session-token",
              "in": "cookie",
              "description": "Session token",
              "schema": {
                "type": "string"
              }
            }
          ],
          "requestBody": {
            "required": true,
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "required": [
                    "name"
                  ],
                  "properties": {
                    "name": {
                      "type": "string"
                    }
                  }
                }
              }
            }
          },
          "responses": {
            "200": {
              "description": "OK",
              "content": {
                "application/json": {
                  "schema": {
                    "type": "object",
                    "properties": {
                      "status": {
                        "type": "string"
                      }
                    }
                  }
                }
              }
            }
          }
        }
      },
      "/lookup": {
        "get": {
          "summary": "Lookup a name",
          "parameters": [
            {
              "name": "page",
              "in": "query",
              "description": "Page number",
              "schema": {
                "type": "integer"
              }
            }
          ],
          "responses": {
            "200": {
              "description": "OK",
              "content": {
                "application/json": {
                  "schema": {
                    "type": "object",
                    "properties": {
                      "status": {
                        "type": "string"
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
  """

  setup do
    tmp_dir =
      System.tmp_dir!()
      |> Path.join("open-api-generator-#{System.unique_integer([:positive])}")

    output_dir = Path.join(tmp_dir, "generated")
    spec_file = Path.join(tmp_dir, "issue104.json")

    File.mkdir_p!(tmp_dir)
    File.write!(spec_file, @spec_json)

    Application.put_env(:oapi_generator, @profile,
      output: [
        base_module: MyClient,
        default_client: Client,
        location: output_dir
      ]
    )

    on_exit(fn ->
      Application.delete_env(:oapi_generator, @profile)
      File.rm_rf!(tmp_dir)
    end)

    {:ok, spec_file: spec_file}
  end

  test "renders and validates non-path request params", %{
    spec_file: spec_file
  } do
    state = OpenAPI.run(to_string(@profile), [spec_file])
    operations_file = Enum.find(state.files, &(&1.location =~ "operations.ex"))
    contents = IO.iodata_to_binary(operations_file.contents)

    assert contents =~ "## Options"
    assert contents =~ "* `x-override-name` (header, required): Override the submitted name"
    assert contents =~ "* `session-token` (cookie): Session token"
    assert contents =~ "def submit_post(body, opts) do"
    assert contents =~ "headers = Keyword.take(opts, [:\"x-override-name\"])"
    assert contents =~ "cookies = Keyword.take(opts, [:\"session-token\"])"
    assert contents =~ "headers: headers"
    assert contents =~ "cookies: cookies"
    assert contents =~ "def lookup_get(opts \\\\ []) do"

    modules = Code.compile_string(contents)

    on_exit(fn ->
      for {module, _bytecode} <- modules do
        :code.purge(module)
        :code.delete(module)
      end
    end)

    {request, _binding} =
      Code.eval_string("""
      MyClient.Operations.submit_post(
        %{name: "Alice"},
        [{:"x-override-name", "Bob"}, {:"session-token", "session-1"}]
      )
      """)

    assert request.headers == [{:"x-override-name", "Bob"}]
    assert request.cookies == [{:"session-token", "session-1"}]
    assert request.body == %{name: "Alice"}

    assert_raise ArgumentError, ~r/x-override-name/, fn ->
      Code.eval_string("MyClient.Operations.submit_post(%{name: \"Alice\"}, [])")
    end

    assert elem(Code.eval_string("MyClient.Operations.lookup_get()"), 0).query == []
    assert elem(Code.eval_string("MyClient.Operations.lookup_get(page: 2)"), 0).query == [page: 2]
  end
end
