module gen

import os

// generate V file for an interface
fn generate_interface_binding(info InterfaceInfo, binding_dir string) {
	interface_name := info.get_name()
	file_name := interface_name.to_lower() + '.v'
	file_path := os.join_path(binding_dir, file_name)
	module_name := os.file_name(binding_dir)
	namespace := info.get_namespace()

	// collect interface methods; freed at end via defer
	n_methods := info.get_n_methods()
	mut methods := []FunctionInfo{}
	for i in 0 .. int(n_methods) {
		m := info.get_method(u32(i)) or { continue }
		methods << m
	}
	defer { for m in methods { m.free() } }

	mut content := 'module ${module_name}\n\n'

	// generate C method declarations
	method_declarations := generate_c_declarations(methods, namespace)
	if method_declarations != '' {
		content += method_declarations
		content += '\n'
	}

	// generate V interface (IFoo)
	content += 'pub interface I${interface_name} {\n'
	for method in methods {
		method_name := method.get_name()

		// skip private methods
		if method_name.starts_with('_') { continue }

		v_method_name := method_name.replace('-', '_')

		// build parameter list
		mut params := []string{}
		n_args := method.get_n_args()
		for j in 0 .. int(n_args) {
			arg := method.get_arg(u32(j)) or { continue }
			direction := arg.get_direction()
			if direction == gi_direction_in {
				arg_name := sanitize_param_name(arg.get_name())
				arg_vtype := arg.get_v_type(namespace)
				params << '${arg_name} ${arg_vtype.name}'
			}
			arg.free()
		}

		param_list := params.join(', ')

		// get return type
		return_type_info := method.get_return_type()
		return_vtype := return_type_info.to_v_type(namespace)
		return_type_info.free()

		skip_return := method.skip_return() || return_vtype.name == 'void'
		can_throw := method.can_throw_gerror()
		may_null := method.may_return_null()

		return_sig := return_vtype.to_v_return_sig(can_throw, may_null, skip_return)
		content += '\t${v_method_name}(${param_list}) ${return_sig}\n'
	}
	content += '}\n\n'

	// generate concrete struct (Foo) for C interop
	content += 'pub struct ${interface_name} {\n'
	content += '\tptr voidptr\n'
	content += '}\n\n'

	// generate methods on concrete struct (thin wrapper around generate_methods)
	content += generate_interface_methods(methods, interface_name, namespace)

	os.write_file(file_path, content) or {
		eprintln('Warning: Failed to write ${file_path}')
		return
	}
}

// generate methods on the concrete interface struct (thin wrapper around generate_methods)
fn generate_interface_methods(methods []FunctionInfo, interface_name string, namespace string) string {
	return generate_methods(methods, interface_name, namespace, map[string]bool{})
}
