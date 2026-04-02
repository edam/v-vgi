module gen

import os

// generate V file for an object
fn generate_object_binding(info ObjectInfo, binding_dir string) {
	object_name := info.get_name()
	file_name := object_name.to_lower() + '.v'
	file_path := os.join_path(binding_dir, file_name)
	namespace := info.get_namespace()
	module_name := os.file_name(binding_dir)

	// collect methods and signals once; freed at end via defer
	methods := info.collect_methods()
	defer { for m in methods { m.free() } }
	signals := info.collect_signals()
	defer { for s in signals { s.free() } }

	// accumulate all required imports: alias → full module path.
	// sub-generators add to this map when they encounter cross-namespace types.
	mut imports := map[string]string{}

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

			imports[module_alias] = 'edam.vgi.${parent_module}'
			parent_embed = '${module_alias}.${parent_name}'
		} else {
			// same namespace - direct embed
			parent_embed = parent_name
		}
	}

	if object_needs_os_import(methods) {
		imports['os'] = 'os'
	}

	// generate body: C declarations, struct, interface, properties, methods.
	// imports are accumulated via the map and prepended after.
	mut body := ''

	// C function declarations
	type_init := info.get_type_init()
	if type_init != '' {
		body += 'fn C.${type_init}() u64\n'
	}
	body += 'fn C.g_object_new_with_properties(object_type u64, n_properties u32, names &&char, values voidptr) voidptr\n'
	body += generate_c_declarations(methods, namespace)
	body += '\n'

	// struct with embedded parent (no implements clause)
	body += 'pub struct ${object_name} {\n'
	if parent_embed != '' {
		body += '\t${parent_embed}\n'
	} else {
		body += '\tptr voidptr\n'
	}
	body += '}\n\n'

	body += generate_object_interface(methods, info, object_name, parent_embed, namespace)
	body += generate_properties_struct(info, object_name, parent_name, parent_embed, namespace, mut imports)
	body += generate_object_constructor(methods, info, object_name, parent_name, namespace)
	body += generate_named_constructors(methods, object_name, namespace)
	body += generate_property_methods(info, object_name, namespace, mut imports)
	body += generate_object_methods(methods, object_name, namespace)
	body += generate_object_interface_implementations(methods, info, object_name, namespace)
	body += generate_signal_bindings(signals, object_name, namespace)

	// assemble file: module declaration, then imports, then body
	mut file_content := 'module ${module_name}\n'
	if imports.len > 0 {
		file_content += '\n'
		for alias, path in imports {
			if alias == path {
				file_content += 'import ${alias}\n'
			} else {
				file_content += 'import ${path} as ${alias}\n'
			}
		}
	}
	file_content += '\n'
	file_content += body

	os.write_file(file_path, file_content) or {
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

	mut content := 'pub fn ${object_name}.new(props ${object_name}Properties) &${object_name} {\n'
	content += '\tmut ns := []&char{}\n'
	content += '\tmut vs := []GValueBuffer{}\n'
	content += '\tdefer { for mut v in vs { C.g_value_unset(voidptr(&v)) } }\n'
	content += collect_gvalue_appends(info, namespace)
	content += '\tptr := C.g_object_new_with_properties(C.${type_init}(), u32(ns.len), ns.data, vs.data)\n'
	content += '\tif ptr == unsafe { nil } { panic(\'g_object_new_with_properties returned null for ${object_name}\') }\n'
	content += '\treturn &${object_name}{ptr: unsafe { voidptr(ptr) }}\n'
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

		if symbol_unavailable(symbol) {
			continue
		}
		v_method_name := method_name.replace('-', '_')
		can_throw := method.can_throw_gerror()
		may_null := method.may_return_null()

		params, call_args, _ := collect_method_params(method, namespace)
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

// collect all method names defined by any ancestor object (not the object itself).
// used to skip method name conflicts when building per-object interface hierarchies.
fn collect_ancestor_method_names(info ObjectInfo) map[string]bool {
	mut names := map[string]bool{}
	if parent := info.get_parent() {
		n := parent.get_n_methods()
		for i in 0 .. int(n) {
			m := parent.get_method(u32(i)) or { continue }
			names[m.get_name().replace('-', '_')] = true
			m.free()
		}
		for k, v in collect_ancestor_method_names(parent) {
			names[k] = v
		}
		parent.free()
	}
	return names
}

// generate V interface IFoo for an object, mirroring the struct hierarchy.
// each interface embeds only its direct parent's interface; root objects include object_ptr().
// parent_embed is the parent struct embed expression (e.g. '' / 'Application' / 'gio.Application').
fn generate_object_interface(methods []FunctionInfo, info ObjectInfo, object_name string, parent_embed string, namespace string) string {
	// collect ancestor method names to avoid interface method conflicts
	// (a subclass may override a method with a different signature, which V disallows in interfaces)
	ancestor_method_names := collect_ancestor_method_names(info)
	// derive parent interface embed from parent_embed
	parent_iface_embed := if parent_embed == '' {
		''
	} else if parent_embed.contains('.') {
		// cross-namespace: 'gio.Application' → 'gio.IApplication'
		parts := parent_embed.split('.')
		'${parts[0]}.I${parts[1]}'
	} else {
		// same namespace: 'Application' → 'IApplication'
		'I${parent_embed}'
	}

	mut content := 'pub interface I${object_name} {\n'
	if parent_iface_embed != '' {
		content += '\t${parent_iface_embed}\n'
	} else {
		// root object: provide object_ptr() as the anchor method
		content += '\tobject_ptr() voidptr\n'
	}

	// add own instance/static methods (mirrors generate_methods logic)
	for method in methods {
		if method.is_constructor() { continue }
		method_name := method.get_name()
		if method_name.starts_with('_') { continue }
		symbol := method.get_symbol()
		if symbol == '' { continue }
		if symbol == 'g_object_get_property' || symbol == 'g_object_set_property' { continue }

		v_method_name := method_name.replace('-', '_')

		// skip methods that an ancestor already defines to avoid interface method conflicts
		// (V disallows two methods with the same name but different signatures in an interface hierarchy)
		if v_method_name in ancestor_method_names { continue }

		// special case: g_application_run is generated as run() int with no params
		if symbol == 'g_application_run' {
			content += '\t${v_method_name}() int\n'
			continue
		}

		params, _, out_params := collect_method_params(method, namespace)
		param_list := params.join(', ')

		return_type_info := method.get_return_type()
		return_vtype := return_type_info.to_v_type(namespace)
		return_type_info.free()

		skip_return := method.skip_return() || return_vtype.name == 'void'
		can_throw := method.can_throw_gerror()
		may_null := method.may_return_null()

		return_sig := build_return_sig(return_vtype, out_params, can_throw, may_null, skip_return)
		if return_sig != '' {
			content += '\t${v_method_name}(${param_list}) ${return_sig}\n'
		} else {
			content += '\t${v_method_name}(${param_list})\n'
		}
	}
	content += '}\n\n'

	// for root objects, generate object_ptr() method on the struct itself
	if parent_embed == '' {
		content += 'pub fn (obj &${object_name}) object_ptr() voidptr {\n'
		content += '\treturn obj.ptr\n'
		content += '}\n\n'
	}

	return content
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
