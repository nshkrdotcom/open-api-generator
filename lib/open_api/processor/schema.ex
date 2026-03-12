defmodule OpenAPI.Processor.Schema do
  @moduledoc """
  Processed schema used by the renderer

  This struct is created by the Processor to hold only the data necessary for rendering schemas
  and their types. It has the following fields:

    * `context`: List of contexts where the schema is found in the API description.
    * `fields`: List of `t:OpenAPI.Processor.Schema.Field.t/0` structs contained in the schema.
    * `module_name`: Name of the module where the schema will be defined.
    * `output_format`: Intended format of the output (ex. struct or typespec).
    * `ref`: Reference of the schema and its original spec in the processor state.
    * `type_name`: Name of the schema's type within its module.

  All of this data is managed by the code generator, and it is unlikely that a callback would
  need to modify this struct directly.
  """
  alias OpenAPI.Processor.Schema.Field
  alias OpenAPI.Processor.Type
  alias OpenAPI.Spec
  alias OpenAPI.Spec.Schema, as: SchemaSpec

  @typedoc "Format of rendering the schema (full struct or inline typespec)"
  @type format :: :struct | :type | :none

  @typedoc "Processed schema used by the renderer"
  @type t :: %__MODULE__{
          context: [tuple],
          description: String.t() | nil,
          deprecated: boolean,
          example: any,
          examples: list() | nil,
          external_docs: Spec.ExternalDocumentation.t() | nil,
          extensions: Spec.extensions(),
          fields: [Field.t()],
          module_name: module,
          output_format: format | nil,
          ref: reference,
          title: String.t() | nil,
          type_name: atom
        }

  defstruct context: [],
            description: nil,
            deprecated: false,
            example: nil,
            examples: nil,
            external_docs: nil,
            extensions: %{},
            fields: [],
            module_name: nil,
            output_format: nil,
            ref: nil,
            title: nil,
            type_name: nil

  #
  # Creation
  #

  @doc false
  @spec map(reference) :: t
  def map(ref) do
    %__MODULE__{
      description: nil,
      deprecated: false,
      example: nil,
      examples: nil,
      external_docs: nil,
      extensions: %{},
      fields: [],
      module_name: nil,
      output_format: :none,
      ref: ref,
      title: nil,
      type_name: :map
    }
  end

  @doc false
  @spec new(reference, SchemaSpec.t(), [Field.t()]) :: t
  def new(ref, schema_spec, fields) do
    %SchemaSpec{
      "$oag_schema_context": context,
      description: description,
      deprecated: deprecated,
      example: example,
      examples: examples,
      external_docs: external_docs,
      extensions: extensions,
      title: title
    } = schema_spec

    %__MODULE__{
      context: context,
      description: description,
      deprecated: deprecated,
      example: example,
      examples: examples,
      external_docs: external_docs,
      extensions: extensions,
      fields: fields,
      module_name: nil,
      output_format: nil,
      ref: ref,
      title: title,
      type_name: nil
    }
  end

  #
  # Modification
  #

  @doc false
  @spec add_context(t, tuple) :: t
  def add_context(%__MODULE__{context: contexts} = schema, new_context) do
    contexts = Enum.uniq([new_context | contexts])
    %__MODULE__{schema | context: contexts}
  end

  @doc false
  @spec merge(t, t) :: t
  def merge(schema_a, schema_b) do
    fields_a = Map.new(schema_a.fields, fn field -> {field.name, field} end)
    fields_b = Map.new(schema_b.fields, fn field -> {field.name, field} end)

    fields =
      Map.merge(fields_a, fields_b, fn name, field_a, field_b ->
        merge_field(name, field_a, field_b)
      end)
      |> Map.values()

    %__MODULE__{
      context: Enum.uniq(schema_a.context ++ schema_b.context),
      description: first_non_nil(schema_a.description, schema_b.description),
      deprecated: schema_a.deprecated or schema_b.deprecated,
      example: first_non_nil(schema_a.example, schema_b.example),
      examples: merge_examples(schema_a.examples, schema_b.examples),
      external_docs: first_non_nil(schema_a.external_docs, schema_b.external_docs),
      extensions: Map.merge(schema_a.extensions, schema_b.extensions),
      fields: fields,
      module_name: schema_a.module_name,
      output_format: schema_a.output_format,
      ref: schema_a.ref,
      title: first_non_nil(schema_a.title, schema_b.title),
      type_name: schema_a.type_name
    }
  end

  @doc false
  @spec merge_contexts(t, SchemaSpec.t()) :: t
  def merge_contexts(
        %__MODULE__{context: contexts} = schema,
        %SchemaSpec{"$oag_schema_context": new_contexts}
      ) do
    contexts = Enum.uniq(new_contexts ++ contexts)
    %__MODULE__{schema | context: contexts}
  end

  @doc false
  @spec put_output_format(t, format) :: t
  def put_output_format(%__MODULE__{} = schema, format) do
    %__MODULE__{schema | output_format: format}
  end

  @doc false
  @spec stable_sort_key(t(), %{optional(reference()) => t()}) :: term()
  def stable_sort_key(%__MODULE__{} = schema, schemas_by_ref \\ %{}) do
    normalize_schema(schema, schemas_by_ref, MapSet.new())
  end

  @doc false
  @spec stable_label(t(), %{optional(reference()) => t()}) :: String.t()
  def stable_label(%__MODULE__{} = schema, schemas_by_ref \\ %{}) do
    [
      module_name_string(schema.module_name) || "anonymous_schema",
      atom_to_string(schema.type_name) || "anonymous_type",
      atom_to_string(schema.output_format) || "none",
      stable_hash(schema, schemas_by_ref)
    ]
    |> Enum.join(".")
  end

  @spec merge_field(String.t(), Field.t(), Field.t()) :: Field.t()
  defp merge_field(name, field_a, field_b) do
    %Field{
      default: first_non_nil(field_a.default, field_b.default),
      description: first_non_nil(field_a.description, field_b.description),
      deprecated: field_a.deprecated or field_b.deprecated,
      example: first_non_nil(field_a.example, field_b.example),
      examples: merge_examples(field_a.examples, field_b.examples),
      external_docs: first_non_nil(field_a.external_docs, field_b.external_docs),
      extensions: Map.merge(field_a.extensions, field_b.extensions),
      name: name,
      nullable: field_a.nullable or field_b.nullable,
      private: field_a.private and field_b.private,
      read_only: field_a.read_only or field_b.read_only,
      required: field_a.required and field_b.required,
      type: Type.merge(field_a.type, field_b.type),
      write_only: field_a.write_only or field_b.write_only
    }
  end

  @spec merge_examples(list() | nil, list() | nil) :: list() | nil
  defp merge_examples(nil, nil), do: nil
  defp merge_examples(nil, examples), do: examples
  defp merge_examples(examples, nil), do: examples
  defp merge_examples(examples_a, examples_b), do: Enum.uniq(examples_a ++ examples_b)

  @spec first_non_nil(term, term) :: term
  defp first_non_nil(nil, fallback), do: fallback
  defp first_non_nil(value, _fallback), do: value

  defp stable_hash(schema, schemas_by_ref) do
    schema
    |> stable_sort_key(schemas_by_ref)
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
    |> binary_part(0, 12)
  end

  defp normalize_schema(%__MODULE__{} = schema, schemas_by_ref, seen) do
    seen =
      case schema.ref do
        ref when is_reference(ref) -> MapSet.put(seen, ref)
        _other -> seen
      end

    [
      module_name: module_name_string(schema.module_name),
      type_name: atom_to_string(schema.type_name),
      output_format: atom_to_string(schema.output_format),
      title: schema.title,
      description: schema.description,
      context:
        schema.context
        |> Enum.map(&normalize_term(&1, schemas_by_ref, seen))
        |> Enum.sort(),
      fields:
        schema.fields
        |> Enum.map(&normalize_field(&1, schemas_by_ref, seen))
        |> Enum.sort()
    ]
  end

  defp normalize_field(%Field{} = field, schemas_by_ref, seen) do
    [
      name: field.name,
      type: normalize_term(field.type, schemas_by_ref, seen),
      required: field.required,
      nullable: field.nullable,
      private: field.private,
      read_only: field.read_only,
      write_only: field.write_only
    ]
  end

  defp normalize_term(reference, schemas_by_ref, seen) when is_reference(reference) do
    case Map.get(schemas_by_ref, reference) do
      %__MODULE__{} = schema ->
        if MapSet.member?(seen, reference),
          do: {:schema_ref, shallow_identity(schema)},
          else: {:schema_ref, shallow_identity(schema)}

      nil ->
        {:schema_ref, "missing"}
    end
  end

  defp normalize_term(%Field{} = field, schemas_by_ref, seen),
    do: normalize_field(field, schemas_by_ref, seen)

  defp normalize_term(%_{} = struct, schemas_by_ref, seen),
    do: struct |> Map.from_struct() |> normalize_term(schemas_by_ref, seen)

  defp normalize_term(map, schemas_by_ref, seen) when is_map(map) do
    map
    |> Enum.map(fn {key, value} ->
      {normalize_term(key, schemas_by_ref, seen), normalize_term(value, schemas_by_ref, seen)}
    end)
    |> Enum.sort()
  end

  defp normalize_term(tuple, schemas_by_ref, seen) when is_tuple(tuple) do
    tuple
    |> Tuple.to_list()
    |> Enum.map(&normalize_term(&1, schemas_by_ref, seen))
    |> List.to_tuple()
  end

  defp normalize_term(list, schemas_by_ref, seen) when is_list(list),
    do: Enum.map(list, &normalize_term(&1, schemas_by_ref, seen))

  defp normalize_term(atom, _schemas_by_ref, _seen) when is_atom(atom), do: Atom.to_string(atom)
  defp normalize_term(value, _schemas_by_ref, _seen), do: value

  defp shallow_identity(%__MODULE__{} = schema) do
    [
      module_name: module_name_string(schema.module_name),
      type_name: atom_to_string(schema.type_name),
      output_format: atom_to_string(schema.output_format),
      title: schema.title,
      description: schema.description,
      field_names: schema.fields |> Enum.map(& &1.name) |> Enum.sort()
    ]
  end

  defp module_name_string(nil), do: nil
  defp module_name_string(module_name) when is_atom(module_name), do: inspect(module_name)

  defp atom_to_string(nil), do: nil
  defp atom_to_string(atom) when is_atom(atom), do: Atom.to_string(atom)
end
