defmodule OpenAPI.Processor.SchemaMetadataTest do
  use ExUnit.Case, async: true

  alias OpenAPI.Processor.Schema
  alias OpenAPI.Spec.ExternalDocumentation
  alias OpenAPI.TestSupport

  @fixture TestSupport.fixture_path("docs-fidelity.yaml")

  test "preserves processed schema metadata" do
    TestSupport.with_profile([], fn profile ->
      state = TestSupport.process!(profile, [@fixture])
      schema = Enum.find(Map.values(state.schemas), &(&1.title == "Widget"))

      assert schema.title == "Widget"
      assert schema.description == "A widget resource."
      assert schema.deprecated
      assert schema.example == %{"id" => "widget-123", "name" => "Primary widget"}
      assert schema.examples == [%{"id" => "widget-example", "name" => "Example widget"}]

      assert schema.external_docs == %ExternalDocumentation{
               description: "Widget schema docs",
               url: "https://example.com/docs/schemas/widget"
             }

      assert schema.extensions == %{"x-schema-level" => "schema extension"}
    end)
  end

  test "merging schemas keeps schema metadata and extensions" do
    docs = %ExternalDocumentation{url: "https://example.com/schema"}

    merged =
      Schema.merge(
        %Schema{
          description: "A widget resource.",
          external_docs: docs,
          extensions: %{"x-a" => 1},
          fields: [],
          ref: make_ref(),
          title: "Widget"
        },
        %Schema{
          deprecated: true,
          example: %{"id" => "widget-123"},
          examples: [%{"id" => "widget-example"}],
          extensions: %{"x-b" => 2},
          fields: [],
          ref: make_ref()
        }
      )

    assert merged.title == "Widget"
    assert merged.description == "A widget resource."
    assert merged.deprecated
    assert merged.example == %{"id" => "widget-123"}
    assert merged.examples == [%{"id" => "widget-example"}]
    assert merged.external_docs == docs
    assert merged.extensions == %{"x-a" => 1, "x-b" => 2}
  end
end
