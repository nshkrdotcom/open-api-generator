defmodule OpenAPI.Processor.Schema.Field do
  @moduledoc """
  Provides the Field struct that is used by the renderer

  This struct is created by the Processor to hold only the data necessary for rendering fields
  and their types. It has the following fields:

    * `default`: Default value for the field, if any
    * `description`: Field description metadata from the raw schema
    * `deprecated`: Whether the field is marked as deprecated
    * `example`: Example value for the field, if any
    * `examples`: Example collection from the raw schema, if any
    * `external_docs`: External docs metadata for the field, if any
    * `extensions`: Generic `x-*` metadata from the raw schema
    * `name`: Name of the field in its parent schema
    * `nullable`: Whether the field is defined as nullable
    * `private`: Whether the field was added via the `output.extra_fields` configuration
    * `read_only`: Whether the field is marked read-only
    * `required`: Whether the field is marked as required by its parent schema
    * `type`: Internal representation of the field's type
    * `write_only`: Whether the field is marked write-only

  """
  alias OpenAPI.Processor.Type
  alias OpenAPI.Spec
  alias OpenAPI.Spec.ExternalDocumentation

  @typedoc "Processed field data used by the renderer"
  @type t :: %__MODULE__{
          default: any,
          description: String.t() | nil,
          deprecated: boolean,
          example: any,
          examples: list() | nil,
          external_docs: ExternalDocumentation.t() | nil,
          extensions: Spec.extensions(),
          name: String.t(),
          nullable: boolean,
          private: boolean,
          read_only: boolean,
          required: boolean,
          type: Type.t(),
          write_only: boolean
        }

  defstruct default: nil,
            description: nil,
            deprecated: false,
            example: nil,
            examples: nil,
            external_docs: nil,
            extensions: %{},
            name: nil,
            nullable: false,
            private: false,
            read_only: false,
            required: false,
            type: nil,
            write_only: false
end
