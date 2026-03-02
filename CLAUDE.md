# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a V module (`edam.vgi`) that provides GObject introspection bindings for the V programming language. It enables V to interface with any GObject-based library (GTK, GDK, GLib, Pango, Cairo, etc.) by generating static bindings from runtime typelib descriptions via libgirepository.

The module generates V binding code dynamically based on GObject introspection data, rather than maintaining hand-written bindings for each library.

## Architecture

### Core Components

- **gi.vsh**: V script that regenerates bindings for a specified GObject library and version. This is the main code generation tool.
- **gen/** subdirectory: Contains the code generation logic
  - **gen/util.v**: Utility functions for the module, including `get_vmod_path()` which resolves paths relative to the module directory
  - **gen/compat.c.v**: C interop layer defining libgirepository-2.0 C function bindings and types. Uses `#pkgconfig` to link with girepository.
  - **gen/gi.v**: V wrapper API for GObject introspection, providing `Repository` struct and methods to query typelib metadata
  - **gen/bind.v**: Top-level binding orchestration — iterates namespace entries and delegates to type-specific generators; also generates shared helper files (`compat.c.v`, `v_util.v`, `README.md`) and enum/flags bindings
  - **gen/bind_obj.v**: Object binding generation — structs, constructors, property accessors, methods, and interface method implementations on objects
  - **gen/bind_inf.v**: Interface binding generation — V interface types and concrete wrapper structs with method implementations
- **v.mod**: Module definition declaring the `vgi` module with dependency on `edam.ggetopt`

### Key Architectural Pattern

This module uses a **code generation pattern** where:
1. Users run `gi.vsh` with a library name and version (e.g., `gtk 4.0`)
2. The script queries GObject introspection (libgirepository) for API metadata
3. Static V bindings are generated and placed in the module directory
4. Users import the generated bindings (e.g., `import edam.vgi.gtk_4_0 as gtk`)

The generated bindings are designed to be regenerated whenever library versions change or APIs are updated.

## Environment Setup

### macOS PKG_CONFIG_PATH Requirement

On macOS, V's pkgconfig integration may not find the `libffi` dependency required by girepository-2.0. You need to set this environment variable before running any commands:

```bash
export PKG_CONFIG_PATH="/usr/local/Homebrew/Library/Homebrew/os/mac/pkgconfig/15"
```

Add this to your shell profile or prefix all commands with it. **All v commands (test, run, etc.) will fail without this.**

## Common Commands

### Display Library Information
Show information about a GObject library (typelib path, version, metadata count):
```bash
v run gi.vsh --info LIBRARY VERSION
v run gi.vsh -i gtk 4.0
```

### Generate Bindings
Generate or regenerate bindings for a GObject library:
```bash
v run gi.vsh LIBRARY VERSION
# Example:
v run gi.vsh gtk 4.0
```

Or run the script directly (if executable):
```bash
./gi.vsh gtk 4.0
```

Options:
- `--info` / `-i`: Display information about the library (typelib path, version, metadata entries)
- `--help`: Display usage information
- `--version`: Show vgi module version

### Testing
Run all tests:
```bash
v test .
```

Run specific test file:
```bash
v test gen/gi_test.v
v test gen/util_test.v
```

Run specific test function:
```bash
v test . -run-only test_function_name
```

Run with detailed statistics:
```bash
v -stats test .
```

### Building/Compiling
Since this is a V module, it doesn't require building itself. However, to check syntax:
```bash
v gen/util.v
v gi.vsh
```

## Development Notes

### Dependencies

- **External**: Requires `libgirepository` (GObject introspection library) installed on the system
  - On macOS: `brew install gtk4` (includes gobject-introspection as dependency)
- **V Module**: Depends on `edam.ggetopt` for command-line option parsing

### GObject Introspection Integration

The module wraps libgirepository-2.0 via C interop:
- **gen/compat.c.v** declares C functions (e.g., `gi_repository_dup_default`, `gi_repository_require`) and opaque types
- **gen/gi.v** provides V-friendly wrappers with error handling and string conversion
- Key APIs: `get_default_repository()`, `Repository.require()`, `Repository.get_n_infos()`, `Repository.get_typelib_path()`

### Path Resolution

The module uses `get_vmod_path()` utility (in gen/util.v) to resolve paths relative to the module's installation directory. This is used in gi.vsh to locate the v.mod file and other resources.

### Command-Line Parsing

gi.vsh uses the `edam.ggetopt` module for option parsing with a declarative options array. The `process_arg()` method handles option callbacks.

### Code Generation Context

When working on binding generation (gen/bind*.v files), remember:
1. Query libgirepository for type information
2. Map GObject types to V types
3. Generate valid V syntax for structs, functions, and method bindings
4. Handle memory management between GObject (ref-counted) and V

### Type Mapping

GObject introspection types are mapped to V types:
- `GI_TYPE_TAG_BOOLEAN` → `bool`
- `GI_TYPE_TAG_INT8/16/32` → `i8/i16/int`
- `GI_TYPE_TAG_UINT8/16/32` → `u8/u16/u32`
- `GI_TYPE_TAG_INT64/UINT64` → `i64/u64`
- `GI_TYPE_TAG_FLOAT/DOUBLE` → `f32/f64`
- `GI_TYPE_TAG_UTF8/FILENAME` → `string`
- `GI_TYPE_TAG_INTERFACE` → `voidptr` (TODO: resolve to actual type)
- Other complex types → `voidptr` (arrays, lists, etc. not yet implemented)

### Cross-Namespace Inheritance

Generated bindings support cross-namespace inheritance by importing dependency bindings:
- When an object's parent is from a different namespace (e.g., `Gtk.Application` inherits from `Gio.Application`), the generator creates an import statement
- Example: `import edam.vgi.gio_2_0 as gio` and embeds `gio.Application`
- Same-namespace parents are embedded directly without imports
- The user must separately generate bindings for dependency namespaces if needed (e.g., generate Gio before compiling Gtk bindings)

## Coding Style

### Comments
- One-line comments should start with lowercase (unless referring to a type name)
  - Good: `// get parent info`, `// Repository instance`
  - Bad: `// Get parent info`
- Keep comments terse
  - Good: `// create/empty directory`
  - Bad: `// create or empty the directory`
- Type names in comments keep their capitalization (e.g., `Repository`, `ObjectInfo`)
- Function comments do not contain function name and answer question "if I can this function it will..."
  - Good: `// return an object`
  - Bad: `// get_object returns an object`

### Testing
- **All new functionality must have unit tests**
- Test files use the `_test.v` suffix (e.g., `bind_test.v`, `util_test.v`)
- Test functions must start with `test_` prefix
- Run tests with: `v test .`
- Aim for clear, descriptive test names that explain what is being tested
- **Always run the full test suite after making changes**: `v test .`
- **Do not run gi.vsh multiple times during testing** - it creates directories and generates many files. Use unit tests instead of repeatedly invoking gi.vsh
- Focus tests on library code (`gen/bind.v`, `gen/bind_obj.v`, `gen/bind_inf.v`, `gen/gi.v`, `gen/util.v`) rather than CLI scripts like `gi.vsh` which are primarily glue code

### Documentation
- **Keep CLAUDE.md up to date** when making significant changes
- Add new commands to the "Common Commands" section
- Document new architectural patterns or components
- Update coding style guidelines if new conventions are established
