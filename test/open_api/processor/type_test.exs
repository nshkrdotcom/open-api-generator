defmodule OpenAPI.Processor.TypeTest do
  use ExUnit.Case, async: true

  alias OpenAPI.Processor.Type

  test "merge flattens unions regardless of merge order" do
    type_a = {:schema_a, :t}
    type_b = {:schema_b, :t}
    type_c = {:schema_c, :t}

    expected =
      {:union,
       [type_a, type_b, type_c]
       |> Enum.uniq()
       |> Enum.sort()}

    assert Type.merge(type_a, {:union, [type_b, type_c]}) == expected
    assert Type.merge({:union, [type_b, type_c]}, type_a) == expected
    assert Type.merge(Type.merge(type_a, type_b), type_c) == expected
  end
end
