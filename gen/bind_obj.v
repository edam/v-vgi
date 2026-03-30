module gen

import os

// collect all methods from an ObjectInfo into a slice.
// caller is responsible for freeing each element.
fn collect_methods(info ObjectInfo) []FunctionInfo {
	mut methods := []FunctionInfo{}
	n := info.get_n_methods()
	for i in 0 .. int(n) {
		method := info.get_method(u32(i)) or { continue }
		methods << method
	}
	return methods
}

// generate V file for an object
fn generate_object_binding(info ObjectInfo, binding_dir string) {
	object_name := info.get_name()
	file_name := object_name.to_lower() + '.v'
	file_path := os.join_path(binding_dir, file_name)
	namespace := info.get_namespace()

	// collect methods once; freed at end via defer
	methods := collect_methods(info)
	defer { for m in methods { m.free() } }

	mut content := 'module ${os.file_name(binding_dir)}\n'

	// get parent and check if cross-namespace
	parent := info.get_parent()
	mut parent_embed := ''
	mut parent_name := ''

	if p := parent {
		parent_name = p.get_name()
		parent_namespace := p.get_namespace()

		if parent_namespace != namespace {
			// cross-namespace parent - need import
			repo := get_default_repository()
			parent_version := repo.get_version(parent_namespace)
			parent_module := get_binding_dir_name(parent_namespace, parent_version)
			module_alias := parent_namespace.to_lower()

			content += '\nimport edam.vgi.${parent_module} as ${module_alias}\n'
			parent_embed = '${module_alias}.${parent_name}'
		} else {
			// same namespace - direct embed
			parent_embed = parent_name
		}
	}

	if object_needs_os_import(methods) {
		content += '\nimport os\n'
	}

	content += '\n'

	// generate C function declarations
	type_init := info.get_type_init()
	if type_init != '' {
		content += 'fn C.${type_init}() u64\n'
	}
	// add C.g_object_new declaration for constructor
	content += 'fn C.g_object_new(object_type u64, first_property_name &char) voidptr\n'
	content += generate_c_declarations(methods, namespace)
	content += '\n'

	// struct with embedded parent (no implements clause)
	content += 'pub struct ${object_name} {\n'
	if parent_embed != '' {
		content += '\t${parent_embed}\n'
	} else {
		content += '\tptr voidptr\n'
	}
	content += '}\n\n'

	content += generate_properties_struct(info, object_name, parent_name, parent_embed,
		namespace)
	content += generate_object_constructor(methods, info, object_name, parent_name, namespace)
	content += generate_object_set_properties(info, object_name, parent_name, namespace)
	content += generate_property_methods(info, object_name, namespace)
	content += generate_object_methods(methods, object_name, namespace)
	content += generate_object_interface_implementations(methods, info, object_name, namespace)

	os.write_file(file_path, content) or {
		eprintln('Warning: Failed to write ${file_path}')
		return
	}
}

// collect writable property field names (sanitized snake_case) for an object and all
// its ancestors — mirrors exactly what generate_properties_struct puts in the struct
fn collect_all_property_names(info ObjectInfo) map[string]bool {
	mut names := map[string]bool{}
	n_props := info.get_n_properties()
	for i in 0 .. int(n_props) {
		prop := info.get_property(u32(i)) or { continue }
		if prop.is_writable() {
			names[sanitize_param_name(prop.get_name().replace('-', '_'))] = true
		}
		prop.free()
	}
	if parent := info.get_parent() {
		for name, _ in collect_all_property_names(parent) {
			names[name] = true
		}
		parent.free()
	}
	return names
}

// generate Object.new(properties ObjectProperties) constructor.
// if a specific GI 'new' constructor exists, uses it (pulling args from the properties
// struct by name); otherwise falls back to the generic g_object_new().
fn generate_object_constructor(methods []FunctionInfo, info ObjectInfo, object_name string, parent_name string, namespace string) string {
	// look for a GI constructor named 'new'
	for method in methods {
		if method.is_constructor() && method.get_name() == 'new' {
			return generate_object_gi_constructor(method, info, object_name, parent_name,
				namespace)
		}
	}

	// fall back to g_object_new
	type_init := info.get_type_init()
	if type_init == '' {
		mut content := 'pub fn ${object_name}.new(properties ${object_name}Properties) &${object_name} {\n'
		content += '\tpanic("${object_name}.new() not yet implemented - no type init")\n'
		content += '}\n\n'
		return content
	}

	mut content := 'pub fn ${object_name}.new(properties ${object_name}Properties) &${object_name} {\n'
	content += '\tobj_ptr := C.g_object_new(C.${type_init}(), unsafe { nil })\n'
	content += '\tif obj_ptr == unsafe { nil } { panic(\'g_object_new returned null for ${object_name}\') }\n'
	content += '\tv_object := &${object_name}{ptr: unsafe { voidptr(obj_ptr) }}\n'
	if parent_name != '' {
		content += '\tv_object.${parent_name}.set_properties(properties.${parent_name}Properties)\n'
	}
	content += '\tv_object.set_properties(properties)\n'
	content += '\treturn v_object\n'
	content += '}\n\n'
	return content
}

// generate Object.new(properties ObjectProperties) using a specific GI constructor.
// constructor args are pulled from the properties struct by matching name; any not
// found fall back to a zero/nil default. set_properties() handles the rest.
fn generate_object_gi_constructor(ctor FunctionInfo, info ObjectInfo, object_name string, parent_name string, namespace string) string {
	symbol := ctor.get_symbol()
	can_throw := ctor.can_throw_gerror()
	prop_names := collect_all_property_names(info)

	return_type := if can_throw { '!&${object_name}' } else { '&${object_name}' }
	mut content := 'pub fn ${object_name}.new(properties ${object_name}Properties) ${return_type} {\n'

	mut call_args := []string{}
	n_args := ctor.get_n_args()
	for j in 0 .. int(n_args) {
		arg := ctor.get_arg(u32(j)) or { continue }
		if arg.get_direction() != gi_direction_in {
			arg.free()
			continue
		}

		raw_name := arg.get_name()
		arg_name := sanitize_param_name(raw_name)
		v_prop_name := sanitize_param_name(raw_name.replace('-', '_'))
		arg_vtype := arg.get_v_type(namespace)
		is_enum := arg.is_enum_or_flags()

		if v_prop_name in prop_names {
			if arg_vtype.name == 'string' {
				// string: pass .str if set, nil if not
				content += '\t${arg_name} := if val := properties.${v_prop_name} { val.str } else { unsafe { &char(nil) } }\n'
			} else if is_enum {
				// enum/flags: cast to int for C call; use if/else to avoid or{} type mismatch
				content += '\t${arg_name} := if val := properties.${v_prop_name} { int(val) } else { 0 }\n'
			} else {
				content += '\t${arg_name} := properties.${v_prop_name} or { ${arg_vtype.default_value()} }\n'
			}
		} else {
			// no matching property — use zero/nil default
			if arg_vtype.name == 'string' {
				content += '\t${arg_name} := unsafe { &char(nil) }\n'
			} else if is_enum {
				content += '\t${arg_name} := 0\n'
			} else {
				content += '\t${arg_name} := ${arg_vtype.default_value()}\n'
			}
		}

		call_args << arg_name
		arg.free()
	}

	content += '\tv_result := C.${symbol}(${call_args.join(', ')}'
	if can_throw {
		if call_args.len > 0 {
			content += ', '
		}
		content += 'unsafe { v_get_shared_error() }'
	}
	content += ')\n'
	if can_throw {
		content += '\tv_check_shared_error()!\n'
	}
	if can_throw {
		content += '\tif v_result == unsafe { nil } { return error(\'${symbol} returned null\') }\n'
	} else {
		content += '\tif v_result == unsafe { nil } { panic(\'${symbol} returned null\') }\n'
	}
	content += '\tv_object := &${object_name}{ptr: unsafe { voidptr(v_result) }}\n'
	if parent_name != '' {
		content += '\tv_object.${parent_name}.set_properties(properties.${parent_name}Properties)\n'
	}
	content += '\tv_object.set_properties(properties)\n'
	content += '\treturn v_object\n'
	content += '}\n\n'
	return content
}

// generate object method bindings (thin wrapper around generate_methods)
fn generate_object_methods(methods []FunctionInfo, object_name string, namespace string) string {
	return generate_methods(methods, object_name, namespace, map[string]bool{})
}

// return true if any method requires import os in the generated binding
fn object_needs_os_import(methods []FunctionInfo) bool {
	for method in methods {
		if method.get_symbol() == 'g_application_run' {
			return true
		}
	}
	return false
}

// generate interface method implementations on an object
fn generate_object_interface_implementations(methods []FunctionInfo, info ObjectInfo, object_name string, namespace string) string {
	mut content := ''

	n_interfaces := info.get_n_interfaces()
	if n_interfaces == 0 {
		return content
	}

	// collect all method names from the object itself to detect collisions
	mut object_method_names := map[string]bool{}
	for method in methods {
		v_method_name := method.get_name().replace('-', '_')
		object_method_names[v_method_name] = true
	}

	// also collect property accessor method names
	n_props := info.get_n_properties()
	for i in 0 .. int(n_props) {
		prop := info.get_property(u32(i)) or { continue }
		prop_name := prop.get_name()
		v_prop_name := prop_name.replace('-', '_')

		// track getter and setter names
		if prop.is_readable() {
			object_method_names['get_${v_prop_name}'] = true
		}
		if prop.is_writable() {
			object_method_names['set_${v_prop_name}'] = true
		}

		prop.free()
	}

	for i in 0 .. int(n_interfaces) {
		iface := info.get_interface(u32(i)) or { continue }
		iface_name := iface.get_name()

		content += '// ${iface_name} interface methods\n'

		// collect interface methods; freed at end of this iteration
		n_iface_methods := iface.get_n_methods()
		mut iface_methods := []FunctionInfo{}
		for j in 0 .. int(n_iface_methods) {
			m := iface.get_method(u32(j)) or { continue }
			iface_methods << m
		}

		content += generate_methods(iface_methods, object_name, namespace, object_method_names)

		for m in iface_methods { m.free() }
		iface.free()
	}

	return content
}
