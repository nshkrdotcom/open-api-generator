defmodule OpenAPI.Spec.SecurityAndExtensionsTest do
  use ExUnit.Case, async: true

  alias OpenAPI.Spec.Path.Parameter
  alias OpenAPI.Spec.RequestBody
  alias OpenAPI.Spec.Response
  alias OpenAPI.Spec.Tag
  alias OpenAPI.TestSupport

  @fixture TestSupport.fixture_path("docs-fidelity.yaml")

  test "keeps omitted and explicit empty security distinct" do
    yaml = """
    openapi: 3.0.3
    info:
      title: Security API
      version: 1.0.0
    paths:
      /public:
        get:
          security: []
          responses:
            "200":
              description: OK
      /inherited:
        get:
          responses:
            "200":
              description: OK
    """

    TestSupport.with_temp_spec(yaml, fn spec_file, _dir ->
      TestSupport.with_profile([], fn profile ->
        state = TestSupport.read!(profile, [spec_file])
        assert state.spec.security == nil
        assert state.spec.paths["/public"].get.security == []
        assert state.spec.paths["/inherited"].get.security == nil
      end)
    end)
  end

  test "preserves explicit empty root security" do
    yaml = """
    openapi: 3.0.3
    info:
      title: Security API
      version: 1.0.0
    security: []
    paths:
      /health:
        get:
          responses:
            "200":
              description: OK
    """

    TestSupport.with_temp_spec(yaml, fn spec_file, _dir ->
      TestSupport.with_profile([], fn profile ->
        state = TestSupport.read!(profile, [spec_file])
        assert state.spec.security == []
      end)
    end)
  end

  test "preserves raw security schemes and x- extensions" do
    TestSupport.with_profile([], fn profile ->
      state = TestSupport.read!(profile, [@fixture])
      spec = state.spec

      assert spec.security == [%{"bearerAuth" => []}]
      assert spec.extensions == %{"x-root-owner" => %{"team" => "generator"}}

      [tag] = spec.tags

      assert %Tag{} = tag
      assert tag.extensions == %{"x-tag-group" => "catalog"}
      assert tag.external_docs.url == "https://example.com/docs/tags/widgets"

      get_widget = spec.paths["/widgets/{widget_id}"].get
      post_widget = spec.paths["/widgets"].post

      assert get_widget.security == []
      assert get_widget.extensions == %{"x-trace-category" => "widgets"}
      assert post_widget.security == [%{"bearerAuth" => ["widgets:write"]}]

      path_param = Enum.find(get_widget.parameters, &(&1.name == "widget_id"))
      assert %Parameter{} = path_param
      assert path_param.extensions == %{"x-param-meta" => %{"visibility" => "public"}}

      assert %RequestBody{} = post_widget.request_body
      assert post_widget.request_body.extensions == %{"x-request-body-note" => "widget payload"}

      assert %Response{} = get_widget.responses[200]
      assert get_widget.responses[200].extensions == %{"x-response-note" => "primary response"}

      assert spec.components.security_schemes == %{
               "bearerAuth" => %{
                 "bearerFormat" => "JWT",
                 "description" => "Use a bearer token.",
                 "scheme" => "bearer",
                 "type" => "http",
                 "x-security-meta" => %{"provider" => "example"}
               }
             }

      assert spec.components.schemas["Widget"].extensions == %{
               "x-schema-level" => "schema extension"
             }
    end)
  end
end
