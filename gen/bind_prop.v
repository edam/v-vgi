module gen

// generate @[params] properties struct
fn generate_properties_struct(info ObjectInfo, object_name string, parent_name string, parent_embed string, namespace string, mut imports map[string]string) string {
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
		v_type := prop.get_prop_type(namespace)
		if v_type.import_alias != '' {
			imports[v_type.import_alias] = v_type.import_path
		}

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
		v_type := prop.get_prop_type(namespace)

		value_expr := match v_type.kind {
			.enum_flags   { 'int(val)' }
			.object_iface { 'val.object_ptr()' }
			.object       { 'val.object_ptr()' }
			else          { 'val' }
		}

		content += "\tif val := props.${v_prop_name} { v_gv_${helper}(mut ns, mut vs, c'${prop_name}', ${value_expr}) }\n"

		prop.free()
	}
	return content
}

// recursively collect gvalue append code for an object and all its ancestors
// (ancestors first, so parent properties come before own properties).
// each object's properties are generated using that object's own namespace, so the
// value_expr matches the type used in that object's own Properties struct.
fn collect_gvalue_appends(info ObjectInfo, namespace string) string {
	mut content := ''
	// recurse to ancestors first, using each parent's own namespace
	if parent := info.get_parent() {
		parent_namespace := parent.get_namespace()
		content += collect_gvalue_appends(parent, parent_namespace)
		parent.free()
	}
	content += generate_gvalue_appends_for_object(info, namespace)
	return content
}


// generate property getter/setter methods
fn generate_property_methods(info ObjectInfo, object_name string, namespace string, mut imports map[string]string) string {
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
		v_type := prop.get_prop_type(namespace)
		helper := prop.get_property_helper_name()

		// getter if readable and no method exists
		if prop.is_readable() && 'get_${v_prop_name}' !in method_names {
			if v_type.import_alias != '' { imports[v_type.import_alias] = v_type.import_path }
			raw_result := 'v_getp_${helper}(obj.ptr, \'${prop_name}\')'
			// object_iface getter returns concrete &Foo (not the IFoo interface itself)
			getter_ret_type := if v_type.kind == .object_iface { '&${v_type.concrete_name()}' } else { v_type.name }
			result_expr := match v_type.kind {
				.enum_flags   { 'unsafe { ${v_type.name}(${raw_result}) }' }
				.object_iface { 'unsafe { &${v_type.concrete_name()}(${raw_result}) }' }
				.object       { 'unsafe { ${v_type.name}(${raw_result}) }' }
				else          { raw_result }
			}
			content += 'pub fn (obj &${object_name}) get_${v_prop_name}() ${getter_ret_type} {\n'
			content += '\treturn ${result_expr}\n'
			content += '}\n\n'
		}

		// setter if writable and no method exists
		if prop.is_writable() && 'set_${v_prop_name}' !in method_names {
			if v_type.import_alias != '' { imports[v_type.import_alias] = v_type.import_path }
			set_val := match v_type.kind {
				.enum_flags   { 'int(val)' }
				.object_iface { 'val.object_ptr()' }
				.object       { 'val.object_ptr()' }
				else          { 'val' }
			}
			content += 'pub fn (obj &${object_name}) set_${v_prop_name}(val ${v_type.name}) {\n'
			content += '\tv_setp_${helper}(obj.ptr, \'${prop_name}\', ${set_val})\n'
			content += '}\n\n'
		}

		prop.free()
	}

	return content
}
