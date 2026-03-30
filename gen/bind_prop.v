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
