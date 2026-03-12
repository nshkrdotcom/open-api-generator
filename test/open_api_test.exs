defmodule OpenAPITest do
  use ExUnit.Case, async: true

  alias OpenAPI.TestSupport

  defmodule Client do
    @moduledoc false

    def request(payload), do: payload
  end

  @fixture TestSupport.fixture_path("docs-fidelity.yaml")

  test "run/2 preserves raw and processed metadata in the returned state" do
    TestSupport.with_temp_dir("open-api-state", fn output_dir ->
      TestSupport.with_profile(
        [
          output: [
            base_module: RunStateClient,
            default_client: Client,
            location: output_dir
          ]
        ],
        fn profile ->
          state = TestSupport.run!(profile, [@fixture])

          assert state.spec.security == [%{"bearerAuth" => []}]
          assert state.spec.extensions == %{"x-root-owner" => %{"team" => "generator"}}

          operation =
            Enum.find(state.operations, fn operation ->
              operation.request_method == :get and
                operation.request_path == "/widgets/{widget_id}"
            end)

          inherited_security_operation =
            Enum.find(state.operations, fn operation ->
              operation.request_method == :get and operation.request_path == "/health"
            end)

          assert operation.summary == "Retrieve a widget"
          assert operation.description == "Returns a single widget."
          assert operation.deprecated
          assert operation.tags == ["Widgets"]
          assert operation.security == []
          assert operation.extensions == %{"x-trace-category" => "widgets"}
          assert inherited_security_operation.security == [%{"bearerAuth" => []}]

          assert Enum.any?(operation.response_docs, fn response ->
                   response.status == 200 and
                     response.description == "Widget returned." and
                     response.content_types == [
                       "application/json",
                       "application/vnd.api+json"
                     ]
                 end)

          schema = Enum.find(Map.values(state.schemas), &(&1.title == "Widget"))
          assert schema.description == "A widget resource."
          assert schema.extensions == %{"x-schema-level" => "schema extension"}

          field = Enum.find(schema.fields, &(&1.name == "id"))
          assert field.description == "Widget identifier."
          assert field.extensions == %{"x-field-note" => "field extension"}
        end
      )
    end)
  end
end
