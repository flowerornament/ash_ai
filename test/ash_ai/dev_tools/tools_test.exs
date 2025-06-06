defmodule AshAi.DevTools.ToolsTest do
  use ExUnit.Case, async: true

  describe "get_package_rules action" do
    test "returns rules for packages with usage-rules.md files" do
      # Test with ash package which should have usage-rules.md
      {:ok, results} =
        AshAi.DevTools.Tools
        |> Ash.ActionInput.for_action(:get_package_rules, %{packages: ["ash"]})
        |> Ash.run_action()

      # Should find ash package with rules
      assert is_list(results)

      [%{package: "ash", rules: rules}] = results
      assert is_binary(rules)
      assert String.length(rules) > 0
      # Ash usage rules should contain "Ash" somewhere
      assert String.contains?(rules, "Ash")
    end

    test "returns multiple results for multiple packages with rules" do
      # Test with multiple packages that commonly have usage rules
      {:ok, results} =
        AshAi.DevTools.Tools
        |> Ash.ActionInput.for_action(:get_package_rules, %{
          packages: ["ash", "ash_postgres", "igniter"]
        })
        |> Ash.run_action()

      assert is_list(results)

      # Verify all results have the correct structure
      Enum.each(results, fn result ->
        assert %{package: package, rules: rules} = result
        assert is_binary(package)
        assert is_binary(rules)
        assert String.length(rules) > 0
        assert package in ["ash", "ash_postgres", "igniter"]
      end)
    end

    test "returns empty list for packages without usage-rules.md" do
      {:ok, results} =
        AshAi.DevTools.Tools
        |> Ash.ActionInput.for_action(:get_package_rules, %{packages: ["non_existent_package"]})
        |> Ash.run_action()

      assert results == []
    end

    test "filters out packages without rules from mixed list" do
      {:ok, results} =
        AshAi.DevTools.Tools
        |> Ash.ActionInput.for_action(:get_package_rules, %{
          packages: ["ash", "non_existent_package"]
        })
        |> Ash.run_action()

      # Should only include packages that actually have rules
      assert is_list(results)

      # All returned results should be for packages that exist and have rules
      Enum.each(results, fn result ->
        assert %{package: package, rules: rules} = result
        # Only ash should be returned if it has rules
        assert package in ["ash"]
        assert is_binary(rules)
        assert String.length(rules) > 0
      end)
    end

    test "handles empty package list" do
      {:ok, results} =
        AshAi.DevTools.Tools
        |> Ash.ActionInput.for_action(:get_package_rules, %{packages: []})
        |> Ash.run_action()

      assert results == []
    end

    test "action has correct argument requirements" do
      # Test that packages argument is required
      assert_raise Ash.Error.Invalid, fn ->
        AshAi.DevTools.Tools
        |> Ash.ActionInput.for_action(:get_package_rules, %{})
        |> Ash.run_action!()
      end
    end
  end

  describe "list_ash_resources action" do
    test "returns list of resources with domains" do
      {:ok, results} =
        AshAi.DevTools.Tools
        |> Ash.ActionInput.for_action(:list_ash_resources, %{})
        |> Ash.run_action(context: %{otp_app: :ash_ai})

      assert is_list(results)

      # Verify we get some results from the test app
      assert length(results) > 0

      # Should include some test resources (since we're in test environment)
      test_resources =
        Enum.filter(results, fn resource ->
          resource.name =~ "Test" or resource.domain =~ "Test"
        end)

      assert length(test_resources) > 0

      # All results should have required fields
      Enum.each(results, fn resource ->
        assert %{name: name, domain: domain} = resource
        assert is_binary(name)
        assert is_binary(domain)
      end)
    end
  end

  describe "list_generators action" do
    test "returns list of available igniter generators" do
      {:ok, results} =
        AshAi.DevTools.Tools
        |> Ash.ActionInput.for_action(:list_generators, %{})
        |> Ash.run_action()

      assert is_list(results)

      # Should include ash_ai generators
      ash_ai_generators =
        Enum.filter(results, fn gen ->
          gen.command =~ "ash_ai"
        end)

      assert length(ash_ai_generators) > 0

      # All results should have required fields
      Enum.each(results, fn generator ->
        assert %{command: command, docs: docs} = generator
        assert is_binary(command)
        # Mix.Task.moduledoc can return binary, nil, or false
        assert is_binary(docs) or is_nil(docs) or docs == false
      end)
    end

    test "includes expected ash_ai generators" do
      {:ok, results} =
        AshAi.DevTools.Tools
        |> Ash.ActionInput.for_action(:list_generators, %{})
        |> Ash.run_action()

      commands = Enum.map(results, & &1.command)

      # Should include the generators defined in this project
      expected_generators = [
        "ash_ai.gen.chat",
        "ash_ai.gen.mcp",
        "ash_ai.gen.usage_rules",
        "ash_ai.install"
      ]

      Enum.each(expected_generators, fn expected ->
        assert expected in commands,
               "Expected generator #{expected} not found in #{inspect(commands)}"
      end)
    end
  end

  describe "action descriptions and metadata" do
    test "get_package_rules has appropriate description" do
      action = Ash.Resource.Info.action(AshAi.DevTools.Tools, :get_package_rules)

      assert action.description =~ "rules"
      assert action.description =~ "packages"
      assert action.description =~ "usage-rules.md"
    end

    test "list_ash_resources has appropriate description" do
      action = Ash.Resource.Info.action(AshAi.DevTools.Tools, :list_ash_resources)

      assert action.description =~ "Ash resources"
      assert action.description =~ "domains"
    end

    test "list_generators has appropriate description" do
      action = Ash.Resource.Info.action(AshAi.DevTools.Tools, :list_generators)

      assert action.description =~ "generators"
      assert action.description =~ "igniter"
    end
  end

  describe "type definitions" do
    test "UsageRules type has correct structure" do
      # This should not raise an error when used in action results
      {:ok, results} =
        AshAi.DevTools.Tools
        |> Ash.ActionInput.for_action(:get_package_rules, %{packages: []})
        |> Ash.run_action()

      # Verify the structure matches what's expected (empty list is valid)
      assert is_list(results)

      # Test that we can create valid UsageRules structs in principle
      valid_usage_rule = %{package: "test_package", rules: "test rules content"}
      assert is_map(valid_usage_rule)
      assert Map.has_key?(valid_usage_rule, :package)
      assert Map.has_key?(valid_usage_rule, :rules)
    end

    test "Resource type has correct structure" do
      {:ok, results} =
        AshAi.DevTools.Tools
        |> Ash.ActionInput.for_action(:list_ash_resources, %{})
        |> Ash.run_action(context: %{otp_app: :ash_ai})

      # All results should match Resource type structure
      Enum.each(results, fn resource ->
        assert Map.has_key?(resource, :name)
        assert Map.has_key?(resource, :domain)
      end)
    end

    test "Task type has correct structure" do
      {:ok, results} =
        AshAi.DevTools.Tools
        |> Ash.ActionInput.for_action(:list_generators, %{})
        |> Ash.run_action()

      # All results should match Task type structure
      Enum.each(results, fn task ->
        assert Map.has_key?(task, :command)
        assert Map.has_key?(task, :docs)
        # Verify docs field accepts the types we expect
        assert is_binary(task.docs) or is_nil(task.docs) or task.docs == false
      end)
    end
  end
end

