module gen

import os

// generate V file for all module-level functions in a namespace
fn generate_function_bindings(binding_dir string, namespace string, functions []FunctionInfo) {
	defer {
		for f in functions {
			f.free()
		}
	}

	if functions.len == 0 {
		return
	}

	file_path := os.join_path(binding_dir, 'functions.v')
	module_name := os.file_name(binding_dir)

	mut content := 'module ${module_name}\n\n'

	for func in functions {
		decl := generate_c_method_declaration(func, namespace)
		if decl != '' {
			content += decl
		}
	}
	content += '\n'

	for func in functions {
		content += generate_function_wrapper(func, namespace)
	}

	os.write_file(file_path, content) or {
		eprintln('Warning: Failed to write ${file_path}')
	}
}

fn generate_function_wrapper(func FunctionInfo, namespace string) string {
	func_name := func.get_name()
	if func_name.starts_with('_') {
		return ''
	}
	symbol := func.get_symbol()
	if symbol == '' {
		return ''
	}

	v_func_name := sanitize_param_name(func_name.replace('-', '_').to_lower())
	params, call_args := collect_method_params(func, namespace)
	param_list := params.join(', ')

	return_type_info := func.get_return_type()
	return_vtype := return_type_info.to_v_type(namespace)
	return_type_info.free()

	skip_return := func.skip_return() || return_vtype.name == 'void'
	can_throw := func.can_throw_gerror()
	may_null := func.may_return_null()

	return_sig := return_vtype.to_v_return_sig(can_throw, may_null, skip_return)

	mut out := 'pub fn ${v_func_name}(${param_list}) ${return_sig} {\n'
	out += generate_method_body(symbol, none, call_args, return_vtype, can_throw, may_null,
		skip_return)
	out += '}\n\n'
	return out
}
