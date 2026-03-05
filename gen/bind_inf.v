module gen

import os

// generate V file for an interface
fn generate_interface_binding(info InterfaceInfo, binding_dir string) {
	interface_name := info.get_name()
	file_name := interface_name.to_lower() + '.v'
	file_path := os.join_path(binding_dir, file_name)
	module_name := os.file_name(binding_dir)

	mut content := 'module ${module_name}\n\n'

	// generate C method declarations
	method_declarations := generate_interface_c_method_declarations(info)
	if method_declarations != '' {
		content += method_declarations
		content += '\n'
	}

	// generate V interface (IFoo)
	content += 'pub interface I${interface_name} {\n'
	n_methods := info.get_n_methods()
	for i in 0 .. int(n_methods) {
		method := info.get_method(u32(i)) or { continue }
		method_name := method.get_name()

		// skip private methods
		if method_name.starts_with('_') {
			method.free()
			continue
		}

		v_method_name := method_name.replace('-', '_')

		// build parameter list
		mut params := []string{}
		n_args := method.get_n_args()
		for j in 0 .. int(n_args) {
			arg := method.get_arg(u32(j)) or { continue }
			direction := arg.get_direction()
			if direction == gi_direction_in {
				arg_name := sanitize_param_name(arg.get_name())
				arg_type := arg.get_v_type()
				params << '${arg_name} ${arg_type}'
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
		content += '\t${v_method_name}(${param_list}) ${return_sig}\n'

		method.free()
	}
	content += '}\n\n'

	// generate concrete struct (Foo) for C interop
	content += 'pub struct ${interface_name} {\n'
	content += '\tptr voidptr\n'
	content += '}\n\n'

	// generate methods on concrete struct
	content += generate_interface_methods(info, interface_name)

	os.write_file(file_path, content) or {
		eprintln('Warning: Failed to write ${file_path}')
		return
	}
}

// generate C function declarations for interface methods
fn generate_interface_c_method_declarations(info InterfaceInfo) string {
	mut content := ''

	n_methods := info.get_n_methods()
	for j in 0 .. int(n_methods) {
		method := info.get_method(u32(j)) or { continue }
		content += generate_c_method_declaration(method)
		method.free()
	}

	return content
}

// generate methods on the concrete interface struct
fn generate_interface_methods(info InterfaceInfo, interface_name string) string {
	mut content := ''

	n_methods := info.get_n_methods()
	for i in 0 .. int(n_methods) {
		method := info.get_method(u32(i)) or { continue }
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
		content += 'pub fn (obj &${interface_name}) ${v_method_name}(${param_list}) ${return_sig} {\n'
		content += generate_method_body(symbol, 'obj.ptr', call_args, return_v_type, can_throw,
			may_null, skip_return)
		content += '}\n\n'

		method.free()
	}

	return content
}
