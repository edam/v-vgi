# To Do

## Test Coverage

Unit tests live in `gen/*_test.v`. Functions without direct tests:

### bind_obj.v — covered
- `generate_object_constructor` — `test_generate_object_constructor`
- `generate_object_c_method_declarations` — `test_generate_object_methods`
- `generate_object_methods` — `test_generate_object_methods`
- `generate_object_interface_implementations` — `test_object_interface_implementations`
- `generate_properties_struct` — `test_generate_properties_struct_*`
- `generate_object_set_properties` — `test_generate_object_set_properties_*`
- `generate_property_methods` — `test_generate_property_methods_*`
- `generate_object_binding` — `test_generate_object_binding_creates_file`

### bind.v — not yet tested
- `generate_readme`
- `generate_compat_c`
- `generate_v_util`
- `get_library_c_info`
- `get_c_type`
- `get_c_return_sig`
- `get_v_return_sig`

## Complex Types (gi.v TypeInfo.to_v_type)

Currently return voidptr - need proper handling:
- Arrays (gi_type_tag_array)
- Interfaces (gi_type_tag_interface) - should resolve to actual type name
- Lists (GList, GSList)
- Hash tables (GHashTable)
- Errors (GError)
- Unichar

## Out/Inout Parameters

- Only "in" direction parameters are generated
- Need to handle output parameters (pointers in V)
- Need to handle inout parameters (mut refs)

## Other Metadata Types

Still missing:
- Constants (gi_info_type_constant)
- Structs (non-object, gi_info_type_struct)
- Unions (gi_info_type_union)
- Callbacks (gi_info_type_callback)
- Functions (module-level, not methods)

## Signals

- No signal introspection
- No signal connection methods (connect, disconnect, emit)

## Nullable Types

- may_return_null() is queried but not used
- Should generate ?Type for nullable returns
- Nullable parameters not handled

## Documentation

- No doc comment generation from GI metadata
- Could use gi_base_info_get_attribute() for docs

## Memory Management

- No ref/unref generation for object types
- No free methods for returned structs
- No ownership transfer annotation handling

## Constructors

- Only g_object_new() style constructors
- Missing constructor functions (e.g., gtk_window_new())
- Missing factory methods

## Type Safety

- Interface parameters/returns are voidptr (gi_type_tag_interface not yet resolved)
- Array element types not tracked
- Generic container types not specialized

# Priorities

## High Priority (Needed for basic functionality)

1. DONE - Interface type resolution - Most GObject APIs use interfaces heavily
2. DONE - Enums and flags - Essential for any real API usage
3. DONE - GError handling - ! return types generated, v_check_shared_error() used
4. Nullable return types - Many methods return optional values
5. Constructor functions - Many objects have specific constructors

##  Medium Priority (Needed for real-world usage)

6. Out parameters - Common in GLib/GTK APIs
7. Signals - Core to GObject event system
8. Arrays - Many methods take/return arrays
9. Lists (GList/GSList) - Common in older APIs
10. Module-level functions - Not all functions are methods

##  Low Priority (Nice to have)

11. Documentation comments - Improves developer experience
12. Callbacks - Advanced usage
13. Hash tables - Less common
14. Unions - Rare in modern APIs
15. Memory management annotations - Optimization

# Complete

- Core infrastructure: ~90% complete
- Basic object bindings: ~70% complete (objects, interfaces, enums, error handling work)
- Full API coverage: ~40% complete (constants, structs, unions, callbacks, module functions missing)
- Production ready: ~35% (critical features in place; nullable types, constructors, out params still missing)

The foundation is solid. Error handling, interfaces, and enums are implemented.
Key gaps remaining: nullable returns, named constructors, out parameters, and signals.
