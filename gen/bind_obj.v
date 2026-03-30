module gen

import os

// generate V file for an object
fn generate_object_binding(info ObjectInfo, binding_dir string) {
	object_name := info.get_name()
	file_name := object_name.to_lower() + '.v'
	file_path := os.join_path(binding_dir, file_name)
	namespace := info.get_namespace()

	// collect methods once; freed at end via defer
	methods := info.collect_methods()
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
	content += 'fn C.g_object_new_with_properties(object_type u64, n_properties u32, names &&char, values voidptr) voidptr\n'
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
	content += generate_named_constructors(methods, object_name, namespace)
	content += generate_object_append_gvalues(info, object_name, parent_name, parent_embed,
		namespace)
	content += generate_object_set_properties(info, object_name, parent_name, namespace)
	content += generate_property_methods(info, object_name, namespace)
	content += generate_object_methods(methods, object_name, namespace)
	content += generate_object_interface_implementations(methods, info, object_name, namespace)

	os.write_file(file_path, content) or {
		eprintln('Warning: Failed to write ${file_path}')
		return
	}
}

// generate Object.new(properties ObjectProperties) constructor using g_object_new_with_properties().
// all properties (own + inherited) are collected via append_gvalues() and passed in a single
// g_object_new_with_properties() call — the standard GObject construction pattern.
fn generate_object_constructor(methods []FunctionInfo, info ObjectInfo, object_name string, parent_name string, namespace string) string {
	type_init := info.get_type_init()
	if type_init == '' {
		mut content := 'pub fn ${object_name}.new(properties ${object_name}Properties) &${object_name} {\n'
		content += '\tpanic("${object_name}.new() not yet implemented - no type init")\n'
		content += '}\n\n'
		return content
	}

	mut content := 'pub fn ${object_name}.new(properties ${object_name}Properties) &${object_name} {\n'
	content += '\tmut names := []&char{}\n'
	content += '\tmut values := []GValueBuffer{}\n'
	content += '\tproperties.append_gvalues(mut names, mut values)\n'
	content += '\tobj_ptr := C.g_object_new_with_properties(C.${type_init}(), u32(names.len), names.data, values.data)\n'
	content += '\tfor mut v in values { C.g_value_unset(voidptr(&v)) }\n'
	content += '\tif obj_ptr == unsafe { nil } { panic(\'g_object_new_with_properties returned null for ${object_name}\') }\n'
	content += '\treturn &${object_name}{ptr: unsafe { voidptr(obj_ptr) }}\n'
	content += '}\n\n'
	return content
}

// generate named constructors as separate static factory functions.
// these are thin wrappers around specific C constructors (e.g. gtk_button_new_with_label).
// the "new" constructor is skipped since Object.new(properties) handles it.
fn generate_named_constructors(methods []FunctionInfo, object_name string, namespace string) string {
	mut content := ''
	for method in methods {
		if !method.is_constructor() {
			continue
		}
		method_name := method.get_name()
		if method_name == 'new' {
			continue
		}
		symbol := method.get_symbol()
		if symbol == '' {
			continue
		}

		v_method_name := method_name.replace('-', '_')
		can_throw := method.can_throw_gerror()
		may_null := method.may_return_null()

		params, call_args := collect_method_params(method, namespace)
		param_list := params.join(', ')

		// named constructors return the object type
		return_type := if can_throw {
			'!&${object_name}'
		} else if may_null {
			'?&${object_name}'
		} else {
			'&${object_name}'
		}

		content += 'pub fn ${object_name}.${v_method_name}(${param_list}) ${return_type} {\n'

		mut call := 'C.${symbol}(${call_args.join(', ')}'
		if can_throw {
			if call_args.len > 0 {
				call += ', '
			}
			call += 'unsafe { v_get_shared_error() }'
		}
		call += ')'

		content += '\tv_result := ${call}\n'
		if can_throw {
			content += '\tv_check_shared_error()!\n'
			content += '\tif v_result == unsafe { nil } { return error(\'${symbol} returned null\') }\n'
		} else if may_null {
			content += '\tif v_result == unsafe { nil } { return none }\n'
		} else {
			content += '\tif v_result == unsafe { nil } { panic(\'${symbol} returned null\') }\n'
		}
		content += '\treturn &${object_name}{ptr: unsafe { voidptr(v_result) }}\n'
		content += '}\n\n'
	}
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
