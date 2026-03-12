defmodule OpenAPIGenerationTest do
  use ExUnit.Case, async: false

  alias OpenAPI.TestSupport

  defmodule Client do
    @moduledoc false

    def request(payload), do: payload
  end

  defmodule MetadataRenderer do
    use OpenAPI.Renderer

    alias OpenAPI.Renderer.File
    alias OpenAPI.Renderer.State

    @impl OpenAPI.Renderer
    def render(%State{profile: profile} = state, %File{} = file) do
      test_pid =
        Application.get_env(:oapi_generator, profile, [])
        |> Keyword.fetch!(:test_pid)

      send(test_pid, {:render_file, file.module, file.operations, file.schemas})
      OpenAPI.Renderer.render(state, file)
    end
  end

  @profile :open_api_generation_test
  @docs_fidelity_fixture TestSupport.fixture_path("docs-fidelity.yaml")

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

  test "renders header params into the generated request payload", %{spec_file: spec_file} do
    state = OpenAPI.run(to_string(@profile), [spec_file])
    operations_file = Enum.find(state.files, &(&1.location =~ "operations.ex"))
    contents = IO.iodata_to_binary(operations_file.contents)

    assert contents =~ "headers = Keyword.take(opts, [:\"x-override-name\"])"
    assert contents =~ "headers: headers"

    modules = Code.compile_string(contents)

    on_exit(fn ->
      for {module, _bytecode} <- modules do
        :code.purge(module)
        :code.delete(module)
      end
    end)

    {request, _binding} =
      Code.eval_string("""
      MyClient.Operations.submit_post(%{name: "Alice"}, [{:"x-override-name", "Bob"}])
      """)

    assert request.headers == [{:"x-override-name", "Bob"}]
    assert request.body == %{name: "Alice"}
  end

  test "renderer callbacks can access preserved processed metadata" do
    TestSupport.with_temp_dir("open-api-renderer", fn output_dir ->
      TestSupport.with_profile(
        [
          renderer: MetadataRenderer,
          test_pid: self(),
          output: [
            base_module: RenderMetadataClient,
            default_client: Client,
            location: output_dir
          ]
        ],
        fn profile ->
          _state = TestSupport.run!(profile, [@docs_fidelity_fixture])

          rendered_files = collect_render_files()
          operations = Enum.flat_map(rendered_files, &elem(&1, 1))
          schemas = Enum.flat_map(rendered_files, &elem(&1, 2))

          operation =
            Enum.find(operations, fn operation ->
              operation.request_method == :post and operation.request_path == "/widgets"
            end)

          inherited_security_operation =
            Enum.find(operations, fn operation ->
              operation.request_method == :get and operation.request_path == "/health"
            end)

          assert operation.summary == "Create a widget"
          assert operation.security == [%{"bearerAuth" => ["widgets:write"]}]
          assert operation.extensions == %{"x-trace-category" => "widget-create"}
          assert inherited_security_operation.security == [%{"bearerAuth" => []}]

          assert operation.request_body_docs == %{
                   description: "Widget payload.",
                   required: true,
                   content_types: ["application/json"]
                 }

          assert operation.response_docs == [
                   %{
                     status: 201,
                     description: "Widget created.",
                     content_types: ["application/json"]
                   }
                 ]

          schema = Enum.find(schemas, &(&1.title == "Widget"))
          assert schema.extensions == %{"x-schema-level" => "schema extension"}

          field = Enum.find(schema.fields, &(&1.name == "id"))
          assert field.external_docs.url == "https://example.com/docs/schemas/widget-id"
          assert field.extensions == %{"x-field-note" => "field extension"}
        end
      )
    end)
  end

  defp collect_render_files(acc \\ []) do
    receive do
      {:render_file, module, operations, schemas} ->
        collect_render_files([{module, operations, schemas} | acc])
    after
      0 ->
        Enum.reverse(acc)
    end
  end
end
