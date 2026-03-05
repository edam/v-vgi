# To Do

## Test Coverage

Unit tests live in `gen/*_test.v`. With PKG_CONFIG_PATH set, all tests pass (4 files: util_test.v, bind_test.v, gi_test.v, int_test.v).

### Covered Areas
- **gen/gi_test.v**: Repository loading, info querying, type mapping, basic metadata access.
- **gen/util_test.v**: Path resolution, name sanitization, binding dir naming.
- **gen/bind_test.v**: Binding generation (objects, interfaces, enums), file creation, content validation.
- **gen/int_test.v**: Integer/type handling (likely integration for methods/properties).

### Untested/Not Yet Covered
- **bind.v**: `generate_readme`, `generate_compat_c`, `generate_v_util` — integration-tested via bind_test.v.
- `get_library_c_info`, `get_c_type`, `get_c_return_sig`, `get_v_return_sig` — used but no isolated tests.
- Edge cases: Cross-namespace imports, error paths, large metadata sets.
- New features (e.g., nullables, out params) need tests.

Overall: ~75% test coverage (solid on core; room for edges/complex types). Run with `PKG_CONFIG_PATH=... v test .` for full suite.

## Complex Types (gi.v TypeInfo.to_v_type)

Currently return `voidptr` - need proper handling:
- Arrays (gi_type_tag_array) — not mapped.
- Interfaces (gi_type_tag_interface) — returns `voidptr`; resolution to actual type (e.g., `GioAction`) partially works via parent checks but params/returns stay voidptr.
- Lists (GList, GSList) — voidptr.
- Hash tables (GHashTable) — voidptr.
- Errors (GError) — handled via shared error in methods, but type itself voidptr.
- Unichar — voidptr.

## Out/Inout Parameters

- Only "in" direction parameters generated (gi_direction_in).
- Output (gi_direction_out) and inout (gi_direction_inout) ignored — no pointer/mut ref handling.
- Impacts APIs returning multiple values (common in GLib).

## Other Metadata Types

Still missing full generation:
- Constants (gi_info_type_constant) — not iterated in bind.v.
- Structs (non-object, gi_info_type_struct) — not handled (only objects/interfaces/enums).
- Unions (gi_info_type_union) — not handled.
- Callbacks (gi_info_type_callback) — not handled.
- Functions (module-level, not methods) — bind.v only processes objects/interfaces/enums; no top-level funcs.

## Signals

- No signal introspection (gi_info_type_signal not processed).
- No methods for connect/disconnect/emit.

## Nullable Types

- `may_return_null()` queried but **not used** — returns always non-optional (e.g., `string` not `?string`).
- Parameter nullability (`may_be_null()`) ignored — no `?type` for params.
- `gi_arg_info_is_optional()` not declared/used in compat.c.v.

## Documentation

- No doc comments from GI metadata (gi_base_info_get_attribute not used).

## Memory Management

- No explicit ref/unref methods generated.
- No free() for returned structs (assumes caller manages).
- Ownership transfer (transfer=full/full) not handled — all returns unowned.

## Constructors

- Only generic `g_object_new()` via type_init (if available).
- **Missing** specific constructors (e.g., `gtk_window_new()`) — treated as regular methods.
- No factory methods distinguished.

## Type Safety

- Interface types: voidptr (no resolution to concrete types like `GioAction`).
- Arrays: no element type tracking.
- Generics: no specialization for containers.
- Cross-namespace: imports generated, but types fallback to voidptr if unresolved.

# Priorities

## High Priority (Needed for basic functionality)

1. DONE - Interface type resolution - Parent interfaces embedded; methods implemented on objects.
2. DONE - Enums and flags - Generated with proper V syntax (@[flag] for flags).
3. DONE - GError handling - Shared error via `v_check_shared_error()`; ! returns for throwers.
4. **Nullable return types** - `may_return_null()` ignored; generate `?Type` for optionals (e.g., many GTK returns).
5. **Constructor functions** - Only generic; add specific ctors as distinguished methods.
6. **Out parameters** - Common in APIs; handle as mut refs or out structs.

## Medium Priority (Needed for real-world usage)

7. **Signals** - Essential for events; add gi_info_type_signal processing.
8. **Arrays** - Map to fixed arrays or slices; track element types.
9. Lists (GList/GSList) — Generate list helpers or voidptr with length.
10. **Module-level functions** - Process gi_info_type_function for non-method APIs.
11. **Constants** - Generate const vals from gi_info_type_constant.

## Low Priority (Nice to have)

12. Documentation comments — Pull from GI attrs for godoc.
13. Callbacks — Handle gi_info_type_callback for signals/closures.
14. Hash tables — GHashTable wrappers.
15. Unions — Rare; basic struct mapping.
16. Memory management annotations — Add ref/unref based on transfer=.

# Complete

- Core infrastructure: ~90% complete (GI querying, generation, tests all pass; env setup required).
- Basic object bindings: ~70% complete (structs, in-methods, properties, enums generated/tested; nullables/out-params/signals missing for usability).
- Full API coverage: ~35% complete (objects/interfaces/enums; no constants/structs/unions/callbacks/module-funcs/signals).
- Production ready: ~50% (Compilable, tested bindings for basics; high-pri fixes enable practical GTK/GLib use; cross-ns works).