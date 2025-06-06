# Updated Implementation Plan: Usage Rules MCP Tool Integration

## Project Overview

This project will integrate the functionality of the `usage_rules` hex package into ash_ai's development MCP server. Instead of building from scratch, we'll leverage the existing `usage_rules` package and expose its functionality through MCP tools for AI coding assistants.

**Key Insight**: There's already a commented-out implementation in `lib/ash_ai/dev_tools/tools.ex` that we can uncomment and enhance.

## Current State Analysis

### Existing Infrastructure in ash_ai
1. **MCP Development Server**: `AshAi.Mcp.Dev` plug already exists and handles tool routing
2. **Tool Definition Pattern**: Uses Ash domain DSL with `tools` blocks 
3. **Commented Implementation**: Lines 66-102 in `dev_tools/tools.ex` contain the exact functionality we need
4. **Type Definitions**: `UsageRules` type already defined with proper structure

### Usage Rules Package Analysis
The `usage_rules` package provides:
- `mix usage_rules.sync` - Main command to collect/manage rules
- Automatic discovery of `usage-rules.md` files in dependencies  
- Multiple linking strategies (markdown, @-style for Claude, direct links)
- Status tracking and selective package management

## Simplified Implementation Plan

### Phase 1: Enable Existing Implementation (1-2 hours)

1. **Uncomment the existing code** in `lib/ash_ai/dev_tools/tools.ex` (lines 66-102)
2. **Fix the type reference** - Change `PackageRules` to `UsageRules` (already defined)
3. **Update the tool registration** in `lib/ash_ai/dev_tools.ex` (lines 12-17)
4. **Test the basic functionality** with existing logic

### Phase 2: Enhanced Integration (1-2 days)

Instead of reimplementing functionality, integrate with `usage_rules` package:

```elixir
# Add usage_rules as dependency in mix.exs
{:usage_rules, "~> 0.1", only: [:dev]}

# Enhanced implementation in dev_tools/tools.ex
action :get_package_rules, {:array, UsageRules} do
  description """
  Get usage rules for the provided packages.
  Do this early when working with a given package to understand best practices.
  """

  argument :packages, {:array, :string} do
    allow_nil? false
    description "The packages to get rules for"
  end

  run fn input, _ ->
    input.arguments.packages
    |> Enum.map(&get_package_rules_for/1)
    |> Enum.filter(& &1)
    |> then(&{:ok, &1})
  end
end

action :list_packages_with_rules, {:array, :string} do
  description """
  List all packages in this project that have usage-rules.md files.
  """
  
  run fn _input, _ ->
    Mix.Project.deps_paths()
    |> Enum.filter(fn {_name, path} ->
      Path.join(path, "usage-rules.md") |> File.exists?()
    end)
    |> Enum.map(fn {name, _path} -> to_string(name) end)
    |> then(&{:ok, &1})
  end
end

action :sync_usage_rules, :string do
  description """
  Sync usage rules from all dependencies using the usage_rules package.
  Returns the path to the consolidated rules file.
  """
  
  run fn _input, _ ->
    # Call the usage_rules mix task programmatically
    case System.cmd("mix", ["usage_rules.sync", "--yes"], cd: File.cwd!()) do
      {output, 0} -> {:ok, "usage-rules.md"}
      {error, _} -> {:error, error}
    end
  end
end

defp get_package_rules_for(package_name) do
  Mix.Project.deps_paths()
  |> Enum.find(fn {name, _path} -> to_string(name) == package_name end)
  |> case do
    {name, path} ->
      rules_path = Path.join(path, "usage-rules.md")
      if File.exists?(rules_path) do
        %{
          package: to_string(name),
          rules: File.read!(rules_path)
        }
      end
    nil -> nil
  end
end
```

### Phase 3: Advanced Features (Optional, 1-2 days)

Add convenience tools that leverage `usage_rules` package:

```elixir
action :search_usage_rules, {:array, UsageRules} do
  description """
  Search for specific terms within usage rules across all packages.
  """
  
  argument :query, :string do
    allow_nil? false
    description "Search term to find in usage rules"
  end
  
  # Implementation that searches consolidated rules
end

action :get_consolidated_rules, :string do
  description """
  Get the consolidated usage rules file content if it exists.
  """
  
  run fn _input, _ ->
    case File.read("usage-rules.md") do
      {:ok, content} -> {:ok, content}
      {:error, :enoent} -> {:ok, "No consolidated usage rules found. Run sync_usage_rules first."}
      {:error, reason} -> {:error, reason}
    end
  end
end
```

## Key Changes from Original Plan

### Simplified Architecture
- **No custom modules needed** - leverage existing dev_tools structure
- **No caching layer** - files are read directly (fast enough for development)
- **No custom scanning** - use `Mix.Project.deps_paths()` 
- **No security concerns** - read-only access to known dependency locations

### Integration Points
- **Direct integration** with `usage_rules` package instead of reimplementation
- **Leverage existing patterns** in ash_ai dev tools
- **Use Ash action patterns** instead of custom behaviours
- **Follow existing type definitions** already in the codebase

### Tools Registration

In `lib/ash_ai/dev_tools.ex`, uncomment and update:

```elixir
tools do
  tool :list_ash_resources, AshAi.DevTools.Tools, :list_ash_resources do
    description "List all Ash resources in the app along with their domains"
  end

  tool :get_package_rules, AshAi.DevTools.Tools, :get_package_rules do
    description """
    Get usage rules for the provided packages.
    Do this early when working with a given package to understand best practices.
    """
  end

  tool :list_packages_with_rules, AshAi.DevTools.Tools, :list_packages_with_rules do
    description "List all packages that have usage-rules.md files"
  end

  tool :sync_usage_rules, AshAi.DevTools.Tools, :sync_usage_rules do
    description "Sync usage rules from dependencies using the usage_rules package"
  end

  tool :list_generators, AshAi.DevTools.Tools, :list_generators do
    description "List available generators and their documentation"
  end
end
```

## Testing Strategy

### Unit Tests
```elixir
defmodule AshAi.DevTools.ToolsTest do
  use ExUnit.Case
  
  test "get_package_rules returns rules for existing packages" do
    # Test with ash package which should have usage-rules.md
    {:ok, results} = Ash.run_action(AshAi.DevTools.Tools, :get_package_rules, %{packages: ["ash"]})
    
    assert [%{package: "ash", rules: rules}] = results
    assert is_binary(rules)
    assert String.contains?(rules, "Ash")
  end
  
  test "list_packages_with_rules returns packages with rules" do
    {:ok, packages} = Ash.run_action(AshAi.DevTools.Tools, :list_packages_with_rules, %{})
    
    assert is_list(packages)
    # Should include ash and potentially other packages
  end
end
```

### Integration Tests
- Test MCP protocol compliance with actual Claude Desktop connection
- Verify tool execution through the development server
- Test error handling for missing packages/files

## Implementation Steps

1. **Add dependency** - Add `usage_rules` to mix.exs dev dependencies ✅ **COMPLETED**
2. **Uncomment existing code** - Enable the commented implementation ✅ **COMPLETED**
3. **Fix type reference** - Update `PackageRules` to `UsageRules` ✅ **COMPLETED**
4. **Enable tool registration** - Uncomment the tool definition ✅ **COMPLETED**
5. **Add enhanced actions** - Implement list and sync functionality ⏳ **PENDING**
6. **Test integration** - Verify MCP functionality works ⏳ **PENDING**
7. **Write tests** - Add comprehensive test coverage ⏳ **PENDING**
8. **Documentation** - Update any relevant docs ⏳ **PENDING**

## Progress Update (Current Status)

### ✅ Phase 1 Complete: Basic Implementation (2025-01-06)

**Commit:** `4cba7dd` - "feat: add usage rules MCP tool integration"

**What was accomplished:**
- Added `usage_rules ~> 0.1` dependency to `mix.exs` (dev only)
- Uncommented and fixed the existing `get_package_rules` action in `lib/ash_ai/dev_tools/tools.ex`
- Fixed type reference from `PackageRules` to `UsageRules` (type already existed)
- Fixed package field to use `to_string(name)` for proper serialization
- Enabled tool registration in `lib/ash_ai/dev_tools.ex` domain
- Tested functionality - successfully finds and retrieves rules from packages like `ash`, `ash_postgres`, `ash_phoenix`, `igniter`, `ash_oban`

**Verification:**
- `mix deps.get` and `mix compile` successful
- Manual testing confirmed the logic works correctly
- Found 5+ packages with usage-rules.md files in current dependencies
- Successfully retrieves rules content (e.g., ash package has 33KB of rules)

### ✅ Phase 1 Testing Complete: Comprehensive Test Coverage (2025-01-07)

**Additional accomplishments:**
- Added comprehensive test suite in `test/ash_ai/dev_tools/tools_test.exs`
- 15 tests covering all existing functionality:
  - `get_package_rules` action with various scenarios (existing packages, non-existent, mixed lists, empty lists)
  - `list_ash_resources` action functionality
  - `list_generators` action with igniter generator detection
  - Type definitions validation (UsageRules, Resource, Task)
  - Action metadata and descriptions
- Discovered and handled edge cases:
  - `Mix.Task.moduledoc()` can return `false` for undocumented tasks
  - Test environment resource discovery patterns
- All tests passing with 100% success rate

### ✅ Phase 2 Complete: Enhanced Integration (2025-01-07)

**Commit:** `1aba1fc` - "feat: add list_packages_with_rules MCP tool"

**What was accomplished:**
- Added `list_packages_with_rules` action to `lib/ash_ai/dev_tools/tools.ex`
- Registered new tool in `lib/ash_ai/dev_tools.ex` domain for MCP exposure
- Added comprehensive test coverage for the new action
- Focused on read-only discovery functionality (excluded `sync_usage_rules` after discussion)
- Clean, focused API for package discovery without project modification

**Design Decisions:**
- **Excluded sync_usage_rules**: Determined that syncing is a manual project maintenance task, not something AI assistants should do automatically
- **Read-only approach**: Both tools (`get_package_rules` and `list_packages_with_rules`) are purely for discovery and consumption
- **Simple interface**: `list_packages_with_rules` returns just package names as strings for easy consumption

**Verification:**
- All 17 tests passing including new functionality
- Clean separation of concerns between discovery and consumption
- Consistent with existing dev tools patterns

**Next Steps:**
- Test MCP protocol integration manually
- Consider additional convenience features if needed

## Benefits of This Approach

1. **Faster implementation** - Leverage existing code and package
2. **Standard compliance** - Use established `usage_rules` patterns
3. **Community alignment** - Support the broader usage-rules initiative
4. **Maintainability** - Less custom code to maintain
5. **Consistency** - Follows ash_ai's existing patterns exactly
6. **Feature completeness** - Get all usage_rules functionality for free

This approach transforms what was originally a complex 4-week project into a simple 1-2 day enhancement by leveraging existing infrastructure and the purpose-built `usage_rules` package.