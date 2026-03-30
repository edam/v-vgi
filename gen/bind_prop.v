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

// generate the gvalue append code for a single object's writable properties.
// generates one line per property using gv_append_* helpers.
// `properties` refers to the constructor parameter name.
fn generate_gvalue_appends_for_object(info ObjectInfo, namespace string) string {
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
		v_type := prop.get_v_type(namespace)

		// enums/flags: cast to int; concrete object types: extract .ptr; else pass directly
		is_enum := helper == 'int' && prop.get_type_info().get_tag() == gi_type_tag_interface
		value_expr := if is_enum {
			'int(val)'
		} else if helper == 'object' && v_type.name != 'voidptr' {
			'val.ptr'
		} else {
			'val'
		}

		content += "\tif val := props.${v_prop_name} { v_gv_${helper}(mut ns, mut vs, c'${prop_name}', ${value_expr}) }\n"

		prop.free()
	}
	return content
}

// recursively collect gvalue append code for an object and all its ancestors
// (ancestors first, so parent properties come before own properties)
fn collect_gvalue_appends(info ObjectInfo, namespace string) string {
	mut content := ''
	// recurse to ancestors first
	if parent := info.get_parent() {
		content += collect_gvalue_appends(parent, namespace)
		parent.free()
	}
	content += generate_gvalue_appends_for_object(info, namespace)
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
			raw_result := 'v_getp_${helper}(obj.ptr, \'${prop_name}\')'
			result_expr := if v_type.is_enum {
				'unsafe { ${v_type.name}(${raw_result}) }'
			} else if helper == 'object' && v_type.name != 'voidptr' {
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
			set_val := if v_type.is_enum {
				'int(val)'
			} else if helper == 'object' && v_type.name != 'voidptr' {
				'val.ptr'
			} else {
				'val'
			}
			content += 'pub fn (obj &${object_name}) set_${v_prop_name}(val ${v_type.name}) {\n'
			content += '\tv_setp_${helper}(obj.ptr, \'${prop_name}\', ${set_val})\n'
			content += '}\n\n'
		}

		prop.free()
	}

	return content
}
