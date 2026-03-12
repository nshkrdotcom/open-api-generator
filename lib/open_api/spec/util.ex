defmodule OpenAPI.Spec.Util do
  @moduledoc false

  alias OpenAPI.Spec

  @spec extensions(map) :: Spec.extensions()
  def extensions(yaml) when is_map(yaml) do
    Enum.reduce(yaml, %{}, fn
      {"x-" <> _ = key, value}, acc ->
        Map.put(acc, key, preserve_value(value))

      _entry, acc ->
        acc
    end)
  end

  @spec security_requirements(map) :: Spec.security_requirements() | nil
  def security_requirements(yaml) when is_map(yaml) do
    case Map.fetch(yaml, "security") do
      {:ok, requirements} when is_list(requirements) ->
        Enum.map(requirements, &security_requirement/1)

      {:ok, _value} ->
        nil

      :error ->
        nil
    end
  end

  @spec security_schemes(map) :: %{optional(String.t()) => Spec.security_scheme()}
  def security_schemes(%{"securitySchemes" => security_schemes}) when is_map(security_schemes) do
    Map.new(security_schemes, fn {name, scheme} ->
      {to_string(name), preserve_value(scheme)}
    end)
  end

  def security_schemes(_yaml), do: %{}

  @spec security_requirement(map) :: Spec.security_requirement()
  defp security_requirement(requirement) when is_map(requirement) do
    Map.new(requirement, fn {scheme, scopes} ->
      {to_string(scheme), security_scopes(scopes)}
    end)
  end

  defp security_requirement(_requirement), do: %{}

  @spec security_scopes(term) :: [String.t()]
  defp security_scopes(scopes) when is_list(scopes) do
    Enum.map(scopes, &to_string/1)
  end

  defp security_scopes(nil), do: []
  defp security_scopes(scope), do: [to_string(scope)]

  @spec preserve_value(term) :: term
  defp preserve_value(value) when is_map(value) do
    Map.new(value, fn {key, nested_value} ->
      {to_string(key), preserve_value(nested_value)}
    end)
  end

  defp preserve_value(value) when is_list(value), do: Enum.map(value, &preserve_value/1)
  defp preserve_value(value), do: value
end
