defmodule OpenAPI.Processor.SchemaTest do
  use ExUnit.Case, async: true

  alias OpenAPI.Processor.Schema
  alias OpenAPI.Processor.Schema.Field

  test "stable labels distinguish anonymous schemas with different field shapes" do
    ref_a = make_ref()
    ref_b = make_ref()

    schema_a = %Schema{
      ref: ref_a,
      module_name: nil,
      type_name: :map,
      output_format: :typed_map,
      title: nil,
      description: nil,
      deprecated: false,
      example: nil,
      examples: nil,
      external_docs: nil,
      extensions: %{},
      context: [{:field, ref_a, "and"}],
      fields: [%Field{name: "and", required: true, type: :string}]
    }

    schema_b = %Schema{
      ref: ref_b,
      module_name: nil,
      type_name: :map,
      output_format: :typed_map,
      title: nil,
      description: nil,
      deprecated: false,
      example: nil,
      examples: nil,
      external_docs: nil,
      extensions: %{},
      context: [{:field, ref_b, "or"}],
      fields: [%Field{name: "or", required: true, type: :string}]
    }

    schemas_by_ref = %{ref_a => schema_a, ref_b => schema_b}

    refute Schema.stable_label(schema_a, schemas_by_ref) ==
             Schema.stable_label(schema_b, schemas_by_ref)

    refute Schema.stable_sort_key(schema_a, schemas_by_ref) ==
             Schema.stable_sort_key(schema_b, schemas_by_ref)
  end
end
