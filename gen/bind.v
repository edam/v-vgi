module gen

import os

// generate V bindings for a library
pub fn generate_bindings(library string, version string) {
	repo := get_default_repository()

	// load library
	repo.require(library, version) or {
		eprintln('Error: Failed to load library ${library}-${version}')
		eprintln('${err}')
		exit(1)
	}

	// get binding directory name
	dir_name := get_binding_dir_name(library, version)
	binding_dir := get_vmod_path(dir_name)

	// create/empty directory
	if os.exists(binding_dir) {
		os.rmdir_all(binding_dir) or {
			eprintln('Error: Failed to remove existing directory ${binding_dir}')
			eprintln('${err}')
			exit(1)
		}
	}

	os.mkdir_all(binding_dir) or {
		eprintln('Error: Failed to create directory ${binding_dir}')
		eprintln('${err}')
		exit(1)
	}

	// get metadata for generation
	typelib_path := repo.get_typelib_path(library)
	loaded_version := repo.get_version(library)

	// generate helper files
	generate_readme(binding_dir, library, loaded_version, typelib_path)
	generate_v_util(binding_dir)
	generate_compat_c(binding_dir, library, loaded_version)

	// generate object and interface bindings
	n_infos := repo.get_n_infos(library)

	for i in 0 .. int(n_infos) {
		info := repo.get_info(library, i) or { continue }

		match info.get_type() {
			'object' {
				object_info := info.as_object_info()
				generate_object_binding(object_info, binding_dir)
			}
			'interface' {
				interface_info := info.as_interface_info()
				generate_interface_binding(interface_info, binding_dir)
			}
			'enum', 'flags' {
				enum_info := info.as_enum_info()
				generate_enum_binding(enum_info, binding_dir)
			}
			else {}
		}

		info.free()
	}

	module_parts := @MOD.split('.')
	base_module := module_parts[..module_parts.len - 1].join('.')
	println('bindings for ${library}-${version} generated at ${base_module}.${dir_name}')
}

// generate V enum/flags from EnumInfo
fn generate_enum_binding(info EnumInfo, binding_dir string) {
	enum_name := info.get_name()
	file_name := enum_name.to_lower() + '.v'
	file_path := os.join_path(binding_dir, file_name)

	mut content := 'module ${os.file_name(binding_dir)}\n\n'

	// determine if this is flags or enum based on type
	info_type := info.get_type()
	is_flags := info_type == 'flags'

	// generate enum definition
	content += '@[_allow_multiple_values]\n'
	if is_flags {
		content += '@[flag]\n'
	}
	content += 'pub enum ${enum_name} {\n'

	// generate enum values
	n_values := info.get_n_values()
	for i in 0 .. int(n_values) {
		value_info := info.get_value(u32(i)) or { continue }
		value_name := value_info.get_name()
		value_int := value_info.get_value()

		// convert name to snake_case for V enum convention
		// e.g., GTK_ALIGN_FILL -> align_fill
		mut v_name := value_name.to_lower().replace('-', '_')

		// prefix with underscore if name starts with digit
		if v_name.len > 0 && v_name[0].is_digit() {
			v_name = '_' + v_name
		}

		// for flags, don't specify values (V auto-assigns power of 2)
		// for enums, include explicit values
		if is_flags {
			content += '\t${v_name}\n'
		} else {
			content += '\t${v_name} = ${value_int}\n'
		}

		value_info.free()
	}

	content += '}\n'

	// write file
	os.write_file(file_path, content) or {
		eprintln('Failed to write ${file_path}: ${err}')
		return
	}
}

fn generate_c_method_declaration(method FunctionInfo, namespace string) string {
	symbol := method.get_symbol()
	if symbol == '' {
		return ''
	}

	// skip private methods
	method_name := method.get_name()
	if method_name.starts_with('_') {
		return ''
	}

	// build C parameter list (constructors have no receiver)
	mut c_params := if method.is_constructor() { []string{} } else { ['obj voidptr'] }
	n_args := method.get_n_args()

	for j in 0 .. int(n_args) {
		arg := method.get_arg(u32(j)) or { continue }
		direction := arg.get_direction()

		if direction == gi_direction_in {
			arg_name := sanitize_param_name(arg.get_name())
			arg_vtype := arg.get_v_type(namespace)
			c_params << '${arg_name} ${arg_vtype.to_c_type()}'
		}

		arg.free()
	}

	// add GError parameter if method can throw
	if method.can_throw_gerror() {
		c_params << 'error &&C.GError'
	}

	// get return type
	return_type_info := method.get_return_type()
	return_vtype := return_type_info.to_v_type(namespace)
	return_type_info.free()

	skip_return := method.skip_return()

	// generate function signature
	return_sig := return_vtype.to_c_return_sig(skip_return)
	return if return_sig.len == 0 {
		'fn C.${symbol}(${c_params.join(', ')})\n'
	} else {
		'fn C.${symbol}(${c_params.join(', ')}) ${return_sig}\n'
	}
}

// generate C function declarations for a slice of methods
fn generate_c_declarations(methods []FunctionInfo, namespace string) string {
	mut content := ''
	for method in methods {
		content += generate_c_method_declaration(method, namespace)
	}
	return content
}

// generate V method bindings for a slice of FunctionInfo.
// struct_name is the receiver type (e.g. "Application").
// skip_names: method names (snake_case) to skip — used to avoid duplicate
// interface method implementations on objects.
// Note: does NOT free items in methods — caller is responsible.
fn generate_methods(methods []FunctionInfo, struct_name string, namespace string, skip_names map[string]bool) string {
	mut content := ''
	for method in methods {
		method_name := method.get_name()
		if method.is_constructor() { continue }
		if method_name.starts_with('_') { continue }
		symbol := method.get_symbol()
		if symbol == '' { continue }
		// skip low-level property methods (we generate typed accessors instead)
		if symbol == 'g_object_get_property' || symbol == 'g_object_set_property' { continue }
		v_method_name := method_name.replace('-', '_')
		if v_method_name in skip_names { continue }

		// special case: g_application_run - auto-inject os.args
		if symbol == 'g_application_run' {
			content += 'pub fn (obj &${struct_name}) ${v_method_name}() int {\n'
			content += '\targs_c := os.args.map(it.str)\n'
			content += '\treturn C.${symbol}(obj.ptr, os.args.len, voidptr(args_c.data))\n'
			content += '}\n\n'
			continue
		}

		mut params := []string{}
		mut call_args := []string{}
		n_args := method.get_n_args()

		for j in 0 .. int(n_args) {
			arg := method.get_arg(u32(j)) or { continue }
			arg_name := sanitize_param_name(arg.get_name())
			arg_vtype := arg.get_v_type(namespace)
			direction := arg.get_direction()

			if direction == gi_direction_in {
				params << '${arg_name} ${arg_vtype.name}'
				call_arg := if arg_vtype.name == 'string' {
					'${arg_name}.str'
				} else if arg_vtype.is_enum {
					'int(${arg_name})'
				} else {
					arg_name
				}
				call_args << call_arg
			}

			arg.free()
		}

		param_list := params.join(', ')
		return_type_info := method.get_return_type()
		return_vtype := return_type_info.to_v_type(namespace)
		return_type_info.free()

		skip_return := method.skip_return() || return_vtype.name == 'void'
		can_throw := method.can_throw_gerror()
		may_null := method.may_return_null()

		return_sig := return_vtype.to_v_return_sig(can_throw, may_null, skip_return)
		content += 'pub fn (obj &${struct_name}) ${v_method_name}(${param_list}) ${return_sig} {\n'
		content += generate_method_body(symbol, 'obj.ptr', call_args, return_vtype, can_throw,
			may_null, skip_return)
		content += '}\n\n'
	}
	return content
}


// generate the body of a method binding (from C call to return statement)
fn generate_method_body(symbol string, receiver string, call_args []string, return_vtype VType, can_throw bool, may_null bool, skip_return bool) string {
	needs_string_conv := return_vtype.name == 'string'
	needs_enum_cast := return_vtype.is_enum
	is_nullable_type := return_vtype.name == 'string' || return_vtype.name == 'voidptr'
		|| return_vtype.name.starts_with('&')
	effective_may_null := may_null && is_nullable_type
	mut content := ''

	if skip_return {
		content += '\tC.${symbol}(${receiver}'
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
	} else if effective_may_null {
		// nullable return — capture result and check for nil
		content += '\tv_result := C.${symbol}(${receiver}'
		if call_args.len > 0 {
			content += ', ${call_args.join(', ')}'
		}
		if can_throw {
			content += ', unsafe { v_get_shared_error() }'
		}
		content += ')\n'
		if can_throw {
			// !T: check error first, then treat nil as error (V doesn't support !?T)
			content += '\tv_check_shared_error()!\n'
			content += '\tif v_result == unsafe { nil } { return error(\'${symbol} returned null\') }\n'
		} else {
			// ?T: return none for nil
			content += '\tif v_result == unsafe { nil } { return none }\n'
		}
		if needs_string_conv {
			content += '\treturn unsafe { cstring_to_vstring(v_result) }\n'
		} else {
			content += '\treturn v_result\n'
		}
	} else {
		// non-nullable typed return
		if can_throw {
			content += '\tv_result := '
		} else {
			content += '\treturn '
		}
		if needs_string_conv {
			content += 'unsafe { cstring_to_vstring(C.${symbol}(${receiver}'
		} else if needs_enum_cast {
			content += 'unsafe { ${return_vtype.name}(C.${symbol}(${receiver}'
		} else {
			content += 'C.${symbol}(${receiver}'
		}
		if call_args.len > 0 {
			content += ', ${call_args.join(', ')}'
		}
		if can_throw {
			if needs_string_conv || needs_enum_cast {
				// already inside an unsafe block — no extra unsafe wrapper needed
				content += ', v_get_shared_error()'
			} else {
				content += ', unsafe { v_get_shared_error() }'
			}
		}
		if needs_string_conv {
			content += ')) }\n'
		} else if needs_enum_cast {
			content += ')) }\n'
		} else {
			content += ')\n'
		}
		if can_throw {
			content += '\treturn v_check_shared_error_or_return(v_result)\n'
		}
	}
	return content
}
