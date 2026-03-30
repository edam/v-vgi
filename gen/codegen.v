module gen

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

	// build C parameter list (methods have a receiver; constructors and free functions do not)
	mut c_params := if !method.is_constructor() && method.is_method() { ['obj voidptr'] } else { []string{} }
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

// collect the V parameter list and C call-arg list for a method's in-direction args.
// returns (params, call_args) where params is e.g. ["name string", "val int"]
// and call_args is the corresponding C-ready expressions.
fn collect_method_params(method FunctionInfo, namespace string) ([]string, []string) {
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
	return params, call_args
}

// build the C call expression: C.symbol(receiver, args..., optional_error_arg)
// receiver is none for free functions and static-style interface methods.
// in_unsafe: true when the call appears inside an `unsafe {}` block (skips extra wrapper)
fn build_c_call(symbol string, receiver ?string, call_args []string, can_throw bool, in_unsafe bool) string {
	mut all_args := []string{}
	if r := receiver {
		all_args << r
	}
	all_args << call_args
	if can_throw {
		all_args << if in_unsafe { 'v_get_shared_error()' } else { 'unsafe { v_get_shared_error() }' }
	}
	return 'C.${symbol}(${all_args.join(', ')})'
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

		params, call_args := collect_method_params(method, namespace)

		param_list := params.join(', ')
		return_type_info := method.get_return_type()
		return_vtype := return_type_info.to_v_type(namespace)
		return_type_info.free()

		skip_return := method.skip_return() || return_vtype.name == 'void'
		can_throw := method.can_throw_gerror()
		may_null := method.may_return_null()

		return_sig := return_vtype.to_v_return_sig(can_throw, may_null, skip_return)
		receiver := if method.is_method() { ?string('obj.ptr') } else { none }
		content += 'pub fn (obj &${struct_name}) ${v_method_name}(${param_list}) ${return_sig} {\n'
		content += generate_method_body(symbol, receiver, call_args, return_vtype, can_throw,
			may_null, skip_return)
		content += '}\n\n'
	}
	return content
}

// generate the body of a method binding (from C call to return statement)
fn generate_method_body(symbol string, receiver ?string, call_args []string, return_vtype VType, can_throw bool, may_null bool, skip_return bool) string {
	needs_string_conv := return_vtype.name == 'string'
	needs_enum_cast := return_vtype.is_enum
	is_nullable_type := return_vtype.name == 'string' || return_vtype.name == 'voidptr'
		|| return_vtype.name.starts_with('&')
	effective_may_null := may_null && is_nullable_type
	mut content := ''

	if skip_return {
		content += '\t${build_c_call(symbol, receiver, call_args, can_throw, false)}\n'
		if can_throw {
			content += '\tv_check_shared_error()!\n'
		}
	} else if effective_may_null {
		content += '\tv_result := ${build_c_call(symbol, receiver, call_args, can_throw, false)}\n'
		if can_throw {
			content += '\tv_check_shared_error()!\n'
			content += '\tif v_result == unsafe { nil } { return error(\'${symbol} returned null\') }\n'
		} else {
			content += '\tif v_result == unsafe { nil } { return none }\n'
		}
		if needs_string_conv {
			content += '\treturn unsafe { cstring_to_vstring(v_result) }\n'
		} else {
			content += '\treturn v_result\n'
		}
	} else {
		// non-nullable typed return
		in_unsafe := needs_string_conv || needs_enum_cast
		call := build_c_call(symbol, receiver, call_args, can_throw, in_unsafe)
		prefix := if can_throw { '\tv_result := ' } else { '\treturn ' }
		if needs_string_conv {
			content += '${prefix}unsafe { cstring_to_vstring(${call}) }\n'
		} else if needs_enum_cast {
			content += '${prefix}unsafe { ${return_vtype.name}(${call}) }\n'
		} else {
			content += '${prefix}${call}\n'
		}
		if can_throw {
			content += '\treturn v_check_shared_error_or_return(v_result)\n'
		}
	}
	return content
}
