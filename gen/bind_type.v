module gen

import os

// generate_enum_binding generates V enum/flags from EnumInfo
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
