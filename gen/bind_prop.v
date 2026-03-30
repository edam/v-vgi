module gen

// generate @[params] properties struct
fn generate_properties_struct(info ObjectInfo, object_name string, parent_name string, parent_embed string, namespace string) string {
	mut content := '@[params]\n'
	content += 'pub struct ${object_name}Properties {\n'

	if parent_embed != '' {
		content += '\t${parent_embed}Properties\n'
	}
	content += 'pub:\n'

	// add writable properties only
	n_props := info.get_n_properties()
	for i in 0 .. int(n_props) {
		prop := info.get_property(u32(i)) or { continue }

		// only include writable properties (can be set in constructor)
		if !prop.is_writable() {
			prop.free()
			continue
		}

		prop_name := prop.get_name()
		v_prop_name := sanitize_param_name(prop_name.replace('-', '_'))
		v_type := prop.get_v_type(namespace)

		content += '\t${v_prop_name} ?${v_type.name}\n'

		prop.free()
	}

	content += '}\n\n'
	return content
}

// map property helper name to the GType constant ID name used in generated code
fn helper_to_gtype_id(helper string) string {
	return match helper {
		'bool' { 'g_type_boolean_id' }
		'i8' { 'g_type_char_id' }
		'u8' { 'g_type_uchar_id' }
		'int' { 'g_type_int_id' }
		'u32' { 'g_type_uint_id' }
		'i64' { 'g_type_int64_id' }
		'u64' { 'g_type_uint64_id' }
		'f32' { 'g_type_float_id' }
		'f64' { 'g_type_double_id' }
		'string' { 'g_type_string_id' }
		else { 'g_type_pointer_id' }
	}
}

// map property helper name to the C g_value_set_* function name
fn helper_to_gvalue_setter(helper string) string {
	return match helper {
		'bool' { 'g_value_set_boolean' }
		'i8' { 'g_value_set_schar' }
		'u8' { 'g_value_set_uchar' }
		'int' { 'g_value_set_int' }
		'u32' { 'g_value_set_uint' }
		'i64' { 'g_value_set_int64' }
		'u64' { 'g_value_set_uint64' }
		'f32' { 'g_value_set_float' }
		'f64' { 'g_value_set_double' }
		'string' { 'g_value_set_string' }
		else { 'g_value_set_pointer' }
	}
}

// generate the gvalue append code for a single object's writable properties.
// used by generate_object_append_gvalues to flatten the full hierarchy.
fn generate_gvalue_appends_for_object(info ObjectInfo) string {
	mut content := ''
	n_props := info.get_n_properties()
	for i in 0 .. int(n_props) {
		prop := info.get_property(u32(i)) or { continue }

		if !prop.is_writable() {
			prop.free()
			continue
		}

		prop_name := prop.get_name()
		v_prop_name := sanitize_param_name(prop_name.replace('-', '_'))
		helper := prop.get_property_helper_name()
		gtype_id := helper_to_gtype_id(helper)
		gvalue_setter := helper_to_gvalue_setter(helper)

		// enums cast to int, strings to .str, everything else as-is
		value_expr := if helper == 'int' && prop.get_type_info().get_tag() == gi_type_tag_interface {
			'int(value)'
		} else if helper == 'string' {
			'value.str'
		} else {
			'value'
		}

		content += '\tif value := props.${v_prop_name} {\n'
		content += "\t\tnames << c'${prop_name}'\n"
		content += '\t\tmut gv := GValueBuffer{}\n'
		content += '\t\tC.g_value_init(voidptr(&gv), ${gtype_id})\n'
		content += '\t\tC.${gvalue_setter}(voidptr(&gv), ${value_expr})\n'
		content += '\t\tvalues << gv\n'
		content += '\t}\n'

		prop.free()
	}
	return content
}

// recursively collect gvalue append code for an object and all its ancestors
// (ancestors first, so parent properties come before own properties)
fn collect_gvalue_appends(info ObjectInfo) string {
	mut content := ''
	// recurse to ancestors first
	if parent := info.get_parent() {
		content += collect_gvalue_appends(parent)
		parent.free()
	}
	content += generate_gvalue_appends_for_object(info)
	return content
}

// generate append_gvalues() method on Properties struct that collects ALL property
// name/GValue pairs (own + inherited) into arrays for g_object_new_with_properties().
// the full hierarchy is flattened at code-generation time to avoid cross-module calls.
fn generate_object_append_gvalues(info ObjectInfo, object_name string, parent_name string, parent_embed string, namespace string) string {
	mut content := 'fn (props ${object_name}Properties) append_gvalues(mut names []&char, mut values []GValueBuffer) {\n'
	content += collect_gvalue_appends(info)
	content += '}\n\n'
	return content
}

fn generate_object_set_properties(info ObjectInfo, object_name string, parent_name string, namespace string) string {
	mut content := 'pub fn (obj &${object_name}) set_properties(properties ${object_name}Properties) {\n'

	// set each property if provided using property helpers
	n_props := info.get_n_properties()
	for i in 0 .. int(n_props) {
		prop := info.get_property(u32(i)) or { continue }

		// only writable properties are in the Properties struct
		if !prop.is_writable() {
			prop.free()
			continue
		}

		prop_name := prop.get_name()
		v_prop_name := sanitize_param_name(prop_name.replace('-', '_'))
		v_type := prop.get_v_type(namespace)
		helper := prop.get_property_helper_name()
		// cast enum/flags values to int for the helper function
		value_expr := if v_type.is_enum { 'int(value)' } else { 'value' }

		content += '\tif value := properties.${v_prop_name} {\n'
		content += '\t\tset_${helper}_property(obj.ptr, \'${prop_name}\', ${value_expr})\n'
		content += '\t}\n'

		prop.free()
	}

	content += '}\n\n'
	return content
}

// generate property getter/setter methods
fn generate_property_methods(info ObjectInfo, object_name string, namespace string) string {
	mut content := ''

	// collect method names to avoid duplicates
	mut method_names := map[string]bool{}
	n_methods := info.get_n_methods()
	for i in 0 .. int(n_methods) {
		method := info.get_method(u32(i)) or { continue }
		method_name := method.get_name().replace('-', '_')
		method_names[method_name] = true
		method.free()
	}

	n_props := info.get_n_properties()
	for i in 0 .. int(n_props) {
		prop := info.get_property(u32(i)) or { continue }
		prop_name := prop.get_name()
		v_prop_name := sanitize_param_name(prop_name.replace('-', '_'))
		v_type := prop.get_v_type(namespace)
		helper := prop.get_property_helper_name()

		// getter if readable and no method exists
		if prop.is_readable() && 'get_${v_prop_name}' !in method_names {
			raw_result := 'get_${helper}_property(obj.ptr, \'${prop_name}\')'
			result_expr := if v_type.is_enum {
				'unsafe { ${v_type.name}(${raw_result}) }'
			} else {
				raw_result
			}
			content += 'pub fn (obj &${object_name}) get_${v_prop_name}() ${v_type.name} {\n'
			content += '\treturn ${result_expr}\n'
			content += '}\n\n'
		}

		// setter if writable and no method exists
		if prop.is_writable() && 'set_${v_prop_name}' !in method_names {
			set_val := if v_type.is_enum { 'int(value)' } else { 'value' }
			content += 'pub fn (obj &${object_name}) set_${v_prop_name}(value ${v_type.name}) {\n'
			content += '\tset_${helper}_property(obj.ptr, \'${prop_name}\', ${set_val})\n'
			content += '}\n\n'
		}

		prop.free()
	}

	return content
}
