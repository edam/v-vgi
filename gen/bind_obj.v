module gen

import os

// generate V file for an object
fn generate_object_binding(info ObjectInfo, binding_dir string) {
	object_name := info.get_name()
	file_name := object_name.to_lower() + '.v'
	file_path := os.join_path(binding_dir, file_name)
	current_namespace := info.get_namespace()

	mut content := 'module ${os.file_name(binding_dir)}\n'

	// get parent and check if cross-namespace
	parent := info.get_parent()
	mut parent_embed := ''
	mut parent_name := ''

	if p := parent {
		parent_name = p.get_name()
		parent_namespace := p.get_namespace()

		if parent_namespace != current_namespace {
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

	if object_needs_os_import(info) {
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
	content += generate_object_c_method_declarations(info)
	content += '\n'

	// struct with embedded parent (no implements clause)
	content += 'pub struct ${object_name} {\n'
	if parent_embed != '' {
		content += '\t${parent_embed}\n'
	} else {
		content += '\tptr voidptr\n'
	}
	content += '}\n\n'

	content += generate_properties_struct(info, object_name, parent_name, parent_embed)
	content += generate_object_constructor(info, object_name, parent_name)
	content += generate_object_named_constructors(info, object_name)
	content += generate_object_set_properties(info, object_name, parent_name)
	content += generate_property_methods(info, object_name)
	content += generate_object_methods(info, object_name)
	content += generate_object_interface_implementations(info, object_name)

	os.write_file(file_path, content) or {
		eprintln('Warning: Failed to write ${file_path}')
		return
	}
}

// generate @[params] properties struct
fn generate_properties_struct(info ObjectInfo, object_name string, parent_name string, parent_embed string) string {
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

		// convert kebab-case to snake_case
		v_prop_name := prop_name.replace('-', '_')

		// property type matches the helper function name
		v_type := prop.get_property_helper_name()

		content += '\t${v_prop_name} ?${v_type}\n'

		prop.free()
	}

	content += '}\n\n'
	return content
}

// generate Object.new() constructor; skipped if a specific GI 'new' constructor exists
fn generate_object_constructor(info ObjectInfo, object_name string, parent_name string) string {
	if object_has_specific_new(info) {
		return ''
	}
	type_init := info.get_type_init()
	if type_init == '' {
		// no type init function, generate stub
		mut content := 'pub fn ${object_name}.new(properties ${object_name}Properties) &${object_name} {\n'
		content += '\tpanic("${object_name}.new() not yet implemented - no type init")\n'
		content += '}\n\n'
		return content
	}

	mut content := 'pub fn ${object_name}.new(properties ${object_name}Properties) &${object_name} {\n'
	content += '\tobj_ptr := C.g_object_new(C.${type_init}(), unsafe { nil })\n'
	content += '\tobj := &${object_name}{ptr: unsafe { voidptr(obj_ptr) }}\n'

	// setup parent properties
	if parent_name != '' {
		content += '\tobj.${parent_name}.set_properties(properties.${parent_name}Properties)\n'
	}

	content += '\tobj.set_properties(properties)\n'
	content += '\treturn obj\n'
	content += '}\n\n'
	return content
}

fn generate_object_set_properties(info ObjectInfo, object_name string, parent_name string) string {
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
		v_prop_name := prop_name.replace('-', '_')
		v_type := prop.get_property_helper_name()

		content += '\tif value := properties.${v_prop_name} {\n'
		content += '\t\tset_${v_type}_property(obj.ptr, \'${prop_name}\', value)\n'
		content += '\t}\n'

		prop.free()
	}

	content += '}\n\n'
	return content
}

// generate property getter/setter methods
fn generate_property_methods(info ObjectInfo, object_name string) string {
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
		v_prop_name := prop_name.replace('-', '_')

		// property type matches the helper function name
		v_type := prop.get_property_helper_name()

		// getter if readable and no method exists
		if prop.is_readable() && 'get_${v_prop_name}' !in method_names {
			content += 'pub fn (obj &${object_name}) get_${v_prop_name}() ${v_type} {\n'
			content += '\treturn get_${v_type}_property(obj.ptr, \'${prop_name}\')\n'
			content += '}\n\n'
		}

		// setter if writable and no method exists
		if prop.is_writable() && 'set_${v_prop_name}' !in method_names {
			content += 'pub fn (obj &${object_name}) set_${v_prop_name}(value ${v_type}) {\n'
			content += '\tset_${v_type}_property(obj.ptr, \'${prop_name}\', value)\n'
			content += '}\n\n'
		}

		prop.free()
	}

	return content
}

// generate C function declarations for methods
fn generate_object_c_method_declarations(info ObjectInfo) string {
	mut content := ''

	n_methods := info.get_n_methods()
	for i in 0 .. int(n_methods) {
		method := info.get_method(u32(i)) or { continue }
		content += generate_c_method_declaration(method)
		method.free()
	}

	return content
}

// generate object method bindings
fn generate_object_methods(info ObjectInfo, object_name string) string {
	mut content := ''

	n_methods := info.get_n_methods()
	for i in 0 .. int(n_methods) {
		method := info.get_method(u32(i)) or { continue }
		method_name := method.get_name()

		// skip constructors (generated separately as static funcs)
		if method.is_constructor() {
			method.free()
			continue
		}

		// skip private methods
		if method_name.starts_with('_') {
			method.free()
			continue
		}

		symbol := method.get_symbol()
		if symbol == '' {
			method.free()
			continue
		}

		// skip low-level property methods (we generate typed accessors instead)
		if symbol == 'g_object_get_property' || symbol == 'g_object_set_property' {
			method.free()
			continue
		}

		// convert kebab-case to snake_case
		v_method_name := method_name.replace('-', '_')

		// special case: g_application_run - auto-inject os.args
		if symbol == 'g_application_run' {
			content += 'pub fn (obj &${object_name}) ${v_method_name}() int {\n'
			content += '\targs_c := os.args.map(it.str)\n'
			content += '\treturn C.${symbol}(obj.ptr, os.args.len, voidptr(args_c.data))\n'
			content += '}\n\n'
			method.free()
			continue
		}

		// build parameter list and call args
		mut params := []string{}
		mut call_args := []string{}
		n_args := method.get_n_args()

		for j in 0 .. int(n_args) {
			arg := method.get_arg(u32(j)) or { continue }
			arg_name := sanitize_param_name(arg.get_name())
			arg_type := arg.get_v_type()
			direction := arg.get_direction()

			// only handle 'in' parameters for now
			if direction == gi_direction_in {
				params << '${arg_name} ${arg_type}'
				// convert V value to C value if needed
				call_arg := if arg_type == 'string' { '${arg_name}.str' } else { arg_name }
				call_args << call_arg
			}

			arg.free()
		}

		param_list := params.join(', ')

		// get return type
		return_type_info := method.get_return_type()
		return_v_type := return_type_info.to_v_type()
		return_type_info.free()

		skip_return := method.skip_return() || return_v_type == 'void'
		can_throw := method.can_throw_gerror()
		may_null := method.may_return_null()

		// generate method signature
		return_sig := get_v_return_sig(return_v_type, can_throw, may_null, skip_return)
		content += 'pub fn (obj &${object_name}) ${v_method_name}(${param_list}) ${return_sig} {\n'
		content += generate_method_body(symbol, 'obj.ptr', call_args, return_v_type, can_throw,
			may_null, skip_return)
		content += '}\n\n'

		method.free()
	}

	return content
}

// return true if the object has a GI constructor named 'new'
fn object_has_specific_new(info ObjectInfo) bool {
	n_methods := info.get_n_methods()
	for i in 0 .. int(n_methods) {
		method := info.get_method(u32(i)) or { continue }
		is_ctor := method.is_constructor()
		name := method.get_name()
		method.free()
		if is_ctor && name == 'new' {
			return true
		}
	}
	return false
}

// generate named constructors as static functions (e.g. Window.new(), Label.new_with_mnemonic())
fn generate_object_named_constructors(info ObjectInfo, object_name string) string {
	mut content := ''

	n_methods := info.get_n_methods()
	for i in 0 .. int(n_methods) {
		method := info.get_method(u32(i)) or { continue }

		if !method.is_constructor() {
			method.free()
			continue
		}

		method_name := method.get_name()

		// skip private
		if method_name.starts_with('_') {
			method.free()
			continue
		}

		symbol := method.get_symbol()
		if symbol == '' {
			method.free()
			continue
		}

		v_method_name := method_name.replace('-', '_')

		// build parameter list and call args (no receiver)
		mut params := []string{}
		mut call_args := []string{}
		n_args := method.get_n_args()
		for j in 0 .. int(n_args) {
			arg := method.get_arg(u32(j)) or { continue }
			arg_name := sanitize_param_name(arg.get_name())
			arg_type := arg.get_v_type()
			direction := arg.get_direction()

			if direction == gi_direction_in {
				params << '${arg_name} ${arg_type}'
				call_arg := if arg_type == 'string' { '${arg_name}.str' } else { arg_name }
				call_args << call_arg
			}

			arg.free()
		}

		param_list := params.join(', ')
		can_throw := method.can_throw_gerror()

		// constructors always return the object type; always !& since C can return null
		content += 'pub fn ${object_name}.${v_method_name}(${param_list}) !&${object_name} {\n'
		content += '\tv_result := C.${symbol}('
		if call_args.len > 0 {
			content += call_args.join(', ')
		}
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
		content += '\tif v_result == unsafe { nil } { return error(\'${symbol} returned null\') }\n'
		content += '\treturn &${object_name}{ptr: unsafe { voidptr(v_result) }}\n'
		content += '}\n\n'

		method.free()
	}

	return content
}

// return true if any method requires import os in the generated binding
fn object_needs_os_import(info ObjectInfo) bool {
	n_methods := info.get_n_methods()
	for i in 0 .. int(n_methods) {
		method := info.get_method(u32(i)) or { continue }
		symbol := method.get_symbol()
		method.free()
		if symbol == 'g_application_run' {
			return true
		}
	}
	return false
}

// generate interface method implementations on an object
fn generate_object_interface_implementations(info ObjectInfo, object_name string) string {
	mut content := ''

	n_interfaces := info.get_n_interfaces()
	if n_interfaces == 0 {
		return content
	}

	// collect all method names from the object itself to detect collisions
	mut object_method_names := map[string]bool{}
	n_object_methods := info.get_n_methods()
	for i in 0 .. int(n_object_methods) {
		method := info.get_method(u32(i)) or { continue }
		method_name := method.get_name()
		v_method_name := method_name.replace('-', '_')
		object_method_names[v_method_name] = true
		method.free()
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

		// generate each interface method on the object
		n_methods := iface.get_n_methods()
		for j in 0 .. int(n_methods) {
			method := iface.get_method(u32(j)) or { continue }
			method_name := method.get_name()

			// skip private methods
			if method_name.starts_with('_') {
				method.free()
				continue
			}

			symbol := method.get_symbol()
			if symbol == '' {
				method.free()
				continue
			}

			// convert kebab-case to snake_case
			v_method_name := method_name.replace('-', '_')

			// skip if object already has a method with this name
			if v_method_name in object_method_names {
				method.free()
				continue
			}

			// build parameter list and call args
			mut params := []string{}
			mut call_args := []string{}
			n_args := method.get_n_args()

			for k in 0 .. int(n_args) {
				arg := method.get_arg(u32(k)) or { continue }
				arg_name := sanitize_param_name(arg.get_name())
				arg_type := arg.get_v_type()
				direction := arg.get_direction()

				// only handle 'in' parameters for now
				if direction == gi_direction_in {
					params << '${arg_name} ${arg_type}'
					// convert V value to C value if needed
					call_arg := if arg_type == 'string' { '${arg_name}.str' } else { arg_name }
					call_args << call_arg
				}

				arg.free()
			}

			param_list := params.join(', ')

			// get return type
			return_type_info := method.get_return_type()
			return_v_type := return_type_info.to_v_type()
			return_type_info.free()

			skip_return := method.skip_return() || return_v_type == 'void'
			can_throw := method.can_throw_gerror()
			may_null := method.may_return_null()

			// generate method signature
			return_sig := get_v_return_sig(return_v_type, can_throw, may_null, skip_return)
			content += 'pub fn (obj &${object_name}) ${v_method_name}(${param_list}) ${return_sig} {\n'
			content += generate_method_body(symbol, 'obj.ptr', call_args, return_v_type,
				can_throw, may_null, skip_return)
			content += '}\n\n'

			method.free()
		}

		iface.free()
	}

	return content
}
