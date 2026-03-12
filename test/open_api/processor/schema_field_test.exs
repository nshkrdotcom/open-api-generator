defmodule OpenAPI.Processor.SchemaFieldTest do
  use ExUnit.Case, async: true

  alias OpenAPI.Processor.Schema
  alias OpenAPI.Processor.Schema.Field
  alias OpenAPI.Spec.ExternalDocumentation
  alias OpenAPI.TestSupport

  @fixture TestSupport.fixture_path("docs-fidelity.yaml")

  test "preserves processed field metadata from schema properties" do
    TestSupport.with_profile([], fn profile ->
      state = TestSupport.process!(profile, [@fixture])
      schema = Enum.find(Map.values(state.schemas), &(&1.title == "Widget"))
      field = Enum.find(schema.fields, &(&1.name == "id"))

      assert field.description == "Widget identifier."
      assert field.deprecated
      assert field.read_only
      refute field.write_only
      assert field.example == "widget-123"
      assert field.examples == ["widget-abc"]

      assert field.external_docs == %ExternalDocumentation{
               description: "Widget id docs",
               url: "https://example.com/docs/schemas/widget-id"
             }

      assert field.extensions == %{"x-field-note" => "field extension"}
    end)
  end

  test "merging schemas keeps rich field metadata" do
    docs = %ExternalDocumentation{url: "https://example.com/field"}

    field_a = %Field{
      default: 0,
      description: "Original description",
      deprecated: false,
      example: nil,
      examples: nil,
      external_docs: docs,
      extensions: %{"x-a" => true},
      name: "id",
      nullable: false,
      private: false,
      read_only: true,
      required: true,
      type: :string,
      write_only: false
    }

    field_b = %Field{
      description: nil,
      deprecated: true,
      example: "widget-123",
      examples: ["widget-abc"],
      extensions: %{"x-b" => true},
      name: "id",
      nullable: true,
      private: false,
      read_only: false,
      required: true,
      type: :string,
      write_only: true
    }

    merged =
      Schema.merge(
        %Schema{fields: [field_a], ref: make_ref()},
        %Schema{fields: [field_b], ref: make_ref()}
      )

    [field] = merged.fields

    assert field.default == 0
    assert field.description == "Original description"
    assert field.deprecated
    assert field.example == "widget-123"
    assert field.examples == ["widget-abc"]
    assert field.external_docs == docs
    assert field.extensions == %{"x-a" => true, "x-b" => true}
    assert field.nullable
    assert field.read_only
    assert field.required
    assert field.write_only
  end

  test "preserves field metadata when a property is a schema ref" do
    yaml = """
    openapi: 3.0.3
    info:
      title: Referenced Field API
      version: 1.0.0
    paths:
      /widgets:
        get:
          responses:
            "200":
              description: OK
              content:
                application/json:
                  schema:
                    $ref: "#/components/schemas/Widget"
    components:
      schemas:
        Widget:
          title: Widget
          type: object
          required:
            - id
          properties:
            id:
              $ref: "#/components/schemas/WidgetId"
        WidgetId:
          type: string
          description: Widget identifier from the shared schema.
          deprecated: true
          readOnly: true
          example: widget-123
          examples:
            - widget-abc
          externalDocs:
            description: Widget id docs
            url: https://example.com/docs/widget-id
          x-field-note: from ref
    """

    TestSupport.with_temp_spec(yaml, fn spec_file, _dir ->
      TestSupport.with_profile([], fn profile ->
        state = TestSupport.process!(profile, [spec_file])
        schema = Enum.find(Map.values(state.schemas), &(&1.title == "Widget"))
        field = Enum.find(schema.fields, &(&1.name == "id"))

        assert field.description == "Widget identifier from the shared schema."
        assert field.deprecated
        assert field.read_only
        refute field.write_only
        assert field.example == "widget-123"
        assert field.examples == ["widget-abc"]

        assert field.external_docs == %ExternalDocumentation{
                 description: "Widget id docs",
                 url: "https://example.com/docs/widget-id"
               }

        assert field.extensions == %{"x-field-note" => "from ref"}
      end)
    end)
  end
end
