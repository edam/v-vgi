module gen

import os

// generate_c_interface_method_declarations generates C function declarations for interface methods
fn generate_c_interface_method_declarations(info InterfaceInfo) string {
	mut content := ''
	mut has_methods := false

	n_methods := info.get_n_methods()
	for j in 0 .. int(n_methods) {
		method := info.get_method(u32(j)) or { continue }
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

		has_methods = true

		// build C parameter list
		mut c_params := ['obj voidptr']
		n_args := method.get_n_args()

		for k in 0 .. int(n_args) {
			arg := method.get_arg(u32(k)) or { continue }
			direction := arg.get_direction()

			if direction == gi_direction_in {
				arg_type := arg.get_v_type()
				c_type := match arg_type {
					'string' { '&char' }
					'bool' { 'bool' }
					'i8' { 'i8' }
					'u8' { 'u8' }
					'i16' { 'i16' }
					'u16' { 'u16' }
					'int', 'i32' { 'int' }
					'u32' { 'u32' }
					'i64' { 'i64' }
					'u64' { 'u64' }
					'f32' { 'f32' }
					'f64' { 'f64' }
					else { 'voidptr' }
				}
				c_params << 'arg${k} ${c_type}'
			}

			arg.free()
		}

		// add GError parameter if method can throw
		if method.can_throw_gerror() {
			c_params << 'error &&C.GError'
		}

		// get return type
		return_type_info := method.get_return_type()
		return_v_type := return_type_info.to_v_type()
		return_type_info.free()

		skip_return := method.skip_return()

		c_return_type := if skip_return || return_v_type == 'voidptr' {
			'voidptr'
		} else {
			match return_v_type {
				'string' { '&char' }
				'bool' { 'bool' }
				'i8' { 'i8' }
				'u8' { 'u8' }
				'i16' { 'i16' }
				'u16' { 'u16' }
				'int', 'i32' { 'int' }
				'u32' { 'u32' }
				'i64' { 'i64' }
				'u64' { 'u64' }
				'f32' { 'f32' }
				'f64' { 'f64' }
				else { 'voidptr' }
			}
		}

		content += 'fn C.${symbol}(${c_params.join(', ')}) ${c_return_type}\n'

		method.free()
	}

	if has_methods {
		content += '\n'
	}

	return content
}

// generate_interface_binding generates V file for an interface
fn generate_interface_binding(info InterfaceInfo, binding_dir string) {
	interface_name := info.get_name()
	file_name := interface_name.to_lower() + '.v'
	file_path := os.join_path(binding_dir, file_name)
	module_name := os.file_name(binding_dir)

	mut content := 'module ${module_name}\n\n'

	// generate C method declarations
	content += generate_c_interface_method_declarations(info)

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

		// get return type
		return_type_info := method.get_return_type()
		return_v_type := return_type_info.to_v_type()
		return_type_info.free()
		skip_return := method.skip_return()

		param_list := params.join(', ')

		if skip_return {
			content += '\t${v_method_name}(${param_list})\n'
		} else {
			content += '\t${v_method_name}(${param_list}) ${return_v_type}\n'
		}

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

// generate_interface_methods generates methods on the concrete interface struct
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

		skip_return := method.skip_return()
		needs_string_conv := return_v_type == 'string'
		can_throw := method.can_throw_gerror()

		// determine V return type (add ! for error-throwing methods)
		v_return_sig := if skip_return {
			if can_throw { '!' } else { '' }
		} else {
			if can_throw { '!${return_v_type}' } else { return_v_type }
		}

		// generate method signature
		content += 'pub fn (obj &${interface_name}) ${v_method_name}(${param_list}) ${v_return_sig} {\n'

		if skip_return {
			// void return
			content += '\tC.${symbol}(obj.ptr'
			if call_args.len > 0 {
				content += ', ${call_args.join(', ')}'
			}
			if can_throw {
				content += ', unsafe { v_get_shared_error() }'
			}
			content += ')\n'
			if can_throw {
				content += '\tv_check_shared_error()!\n'
			}
		} else {
			// typed return
			if can_throw {
				content += '\tv_result := '
			} else {
				content += '\treturn '
			}
			if needs_string_conv {
				content += 'unsafe { cstring_to_vstring(C.${symbol}(obj.ptr'
			} else {
				content += 'C.${symbol}(obj.ptr'
			}
			if call_args.len > 0 {
				content += ', ${call_args.join(', ')}'
			}
			if can_throw {
				// don't wrap in unsafe if already in unsafe block
				if needs_string_conv {
					content += ', v_get_shared_error()'
				} else {
					content += ', unsafe { v_get_shared_error() }'
				}
			}
			if needs_string_conv {
				content += ')) }\n'
			} else {
				content += ')\n'
			}
			if can_throw {
				content += '\treturn v_check_shared_error_or_return(v_result)\n'
			}
		}
		content += '}\n\n'

		method.free()
	}

	return content
}
