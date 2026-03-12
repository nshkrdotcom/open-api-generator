defmodule OpenAPI.Processor.ParamTest do
  use ExUnit.Case, async: true

  alias OpenAPI.Spec.Schema.Example
  alias OpenAPI.TestSupport

  @fixture TestSupport.fixture_path("docs-fidelity.yaml")

  test "preserves processed parameter metadata" do
    TestSupport.with_profile([], fn profile ->
      state = TestSupport.process!(profile, [@fixture])

      operation =
        Enum.find(state.operations, fn operation ->
          operation.request_method == :get and
            operation.request_path == "/widgets/{widget_id}"
        end)

      path_param = Enum.find(operation.request_path_parameters, &(&1.name == "widget_id"))

      assert path_param.required
      assert path_param.deprecated
      assert path_param.example == "widget-123"

      assert path_param.examples == %{
               "alt" => %Example{
                 description: nil,
                 external_value: nil,
                 summary: "Alternate widget id",
                 value: "widget-456"
               }
             }

      assert path_param.extensions == %{"x-param-meta" => %{"visibility" => "public"}}

      query_param =
        Enum.find(operation.request_query_parameters, &(&1.name == "include_archived"))

      refute query_param.required
      assert query_param.deprecated
      assert query_param.example == true

      assert query_param.examples == %{
               "standard" => %Example{
                 description: nil,
                 external_value: nil,
                 summary: "Standard query",
                 value: false
               }
             }

      assert query_param.extensions == %{"x-param-meta" => %{"visibility" => "query"}}
    end)
  end
end
