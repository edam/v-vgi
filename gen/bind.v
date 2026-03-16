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

// generate README.md with binding metadata
fn generate_readme(binding_dir string, library string, version string, typelib_path string) {
	readme_path := os.join_path(binding_dir, 'README.md')

	readme_content := 'Library: ${library}
Version: ${version}
Typelib: ${typelib_path}
'

	os.write_file(readme_path, readme_content) or {
		eprintln('Error: Failed to write README.md')
		eprintln('${err}')
		exit(1)
	}
}

// return pkg-config name and include path for a library
fn get_library_c_info(library string, version string) (string, string) {
	lib_lower := library.to_lower()
	version_parts := version.split('.')
	version_major := if version_parts.len > 0 { version_parts[0] } else { '' }

	// hardcoded mappings for known libraries
	match lib_lower {
		'glib' {
			return 'glib-2.0', '<glib.h>'
		}
		'gobject' {
			return 'gobject-2.0', '<glib-object.h>'
		}
		'gio' {
			return 'gio-2.0', '<gio/gio.h>'
		}
		'gtk' {
			if version_major == '4' {
				return 'gtk4', '<gtk/gtk.h>'
			} else if version_major == '3' {
				return 'gtk+-3.0', '<gtk/gtk.h>'
			}
			return 'gtk4', '<gtk/gtk.h>'
		}
		'gdk' {
			if version_major == '4' {
				return 'gtk4', '<gdk/gdk.h>'
			} else if version_major == '3' {
				return 'gdk-3.0', '<gdk/gdk.h>'
			}
			return 'gtk4', '<gdk/gdk.h>'
		}
		'pango' {
			return 'pango', '<pango/pango.h>'
		}
		'pangocairo' {
			return 'pangocairo', '<pango/pangocairo.h>'
		}
		'cairo' {
			return 'cairo', '<cairo.h>'
		}
		'atk' {
			return 'atk', '<atk/atk.h>'
		}
		'gdk-pixbuf', 'gdkpixbuf' {
			return 'gdk-pixbuf-2.0', '<gdk-pixbuf/gdk-pixbuf.h>'
		}
		'gmodule' {
			return 'gmodule-2.0', '<glib.h>'
		}
		'gthread' {
			return 'gthread-2.0', '<glib.h>'
		}
		else {
			// fallback: use library-version for pkg-config and library/library.h for include
			pkgconfig_name := '${lib_lower}-${version}'
			include_path := '<${lib_lower}/${lib_lower}.h>'
			return pkgconfig_name, include_path
		}
	}
}

// generate C interop file with pkgconfig and includes
fn generate_compat_c(binding_dir string, library string, version string) {
	compat_path := os.join_path(binding_dir, 'compat.c.v')
	module_name := os.file_name(binding_dir)

	pkgconfig_name, include_path := get_library_c_info(library, version)

	content := 'module ${module_name}

#pkgconfig ${pkgconfig_name}
#include ${include_path}

// C declarations for GObject/GLib functions using voidptr to avoid cross-module type conflicts
fn C.g_object_get_property(object voidptr, property_name &char, value voidptr)
fn C.g_object_set_property(object voidptr, property_name &char, value voidptr)
fn C.g_error_free(error &C.GError)

fn C.g_value_init(value voidptr, g_type u64) voidptr
fn C.g_value_unset(value voidptr)

@[typedef]
pub struct C.GError {
pub:
	message &char
}

fn C.g_value_get_boolean(value voidptr) bool
fn C.g_value_set_boolean(value voidptr, v_boolean bool)
fn C.g_value_get_schar(value voidptr) i8
fn C.g_value_set_schar(value voidptr, v_schar i8)
fn C.g_value_get_uchar(value voidptr) u8
fn C.g_value_set_uchar(value voidptr, v_uchar u8)
fn C.g_value_get_int(value voidptr) int
fn C.g_value_set_int(value voidptr, v_int int)
fn C.g_value_get_uint(value voidptr) u32
fn C.g_value_set_uint(value voidptr, v_uint u32)
fn C.g_value_get_int64(value voidptr) i64
fn C.g_value_set_int64(value voidptr, v_int64 i64)
fn C.g_value_get_uint64(value voidptr) u64
fn C.g_value_set_uint64(value voidptr, v_uint64 u64)
fn C.g_value_get_float(value voidptr) f32
fn C.g_value_set_float(value voidptr, v_float f32)
fn C.g_value_get_double(value voidptr) f64
fn C.g_value_set_double(value voidptr, v_double f64)
fn C.g_value_get_string(value voidptr) &char
fn C.g_value_set_string(value voidptr, v_string &char)
fn C.g_value_get_pointer(value voidptr) voidptr
fn C.g_value_set_pointer(value voidptr, v_pointer voidptr)

'

	os.write_file(compat_path, content) or {
		eprintln('Warning: Failed to write ${compat_path}')
		return
	}
}

// generate helper functions for property access
fn generate_v_util(binding_dir string) {
	util_path := os.join_path(binding_dir, 'v_util.v')
	module_name := os.file_name(binding_dir)

	mut content := 'module ${module_name}

// return a pointer to the shared GError (singleton pattern)
@[unsafe]
fn v_get_shared_error() &&C.GError {
	unsafe {
		mut static gerror := &C.GError(nil)
		return &&C.GError(&gerror)
	}
}

// check the shared GError and throw if set
fn v_check_shared_error() ! {
	gerror_ptr := unsafe { v_get_shared_error() }
	gerror := unsafe { *gerror_ptr }
	if gerror != unsafe { nil } {
		msg := unsafe { cstring_to_vstring(gerror.message) }
		C.g_error_free(gerror)
		unsafe { *gerror_ptr = nil }
		return error(msg)
	}
}

// check the shared GError and either return the value or throw
fn v_check_shared_error_or_return[T](value T) !T {
	gerror_ptr := unsafe { v_get_shared_error() }
	gerror := unsafe { *gerror_ptr }
	if gerror != unsafe { nil } {
		msg := unsafe { cstring_to_vstring(gerror.message) }
		C.g_error_free(gerror)
		unsafe { *gerror_ptr = nil }
		return error(msg)
	}
	return value
}

// convert a nullable C string to a V string, returning empty string for nil
fn v_cstring_or_empty(s &char) string {
	if s == unsafe { nil } { return \'\' }
	return unsafe { cstring_to_vstring(s) }
}

// GValue is a C struct we need to allocate. size based on GValue definition (24 bytes on most systems)
struct GValueBuffer {
	data [24]u8
}

// GLib fundamental type IDs (G_TYPE_MAKE_FUNDAMENTAL(n) = n << 2, stable GLib ABI)
const g_type_char_id = u64(12)
const g_type_uchar_id = u64(16)
const g_type_boolean_id = u64(20)
const g_type_int_id = u64(24)
const g_type_uint_id = u64(28)
const g_type_int64_id = u64(40)
const g_type_uint64_id = u64(44)
const g_type_float_id = u64(56)
const g_type_double_id = u64(60)
const g_type_string_id = u64(64)
const g_type_pointer_id = u64(68)

// helper functions for property access

fn get_bool_property(obj voidptr, prop_name string) bool {
	mut value := GValueBuffer{}
	C.g_value_init(voidptr(&value), g_type_boolean_id)
	C.g_object_get_property(obj, prop_name.str, voidptr(&value))
	result := C.g_value_get_boolean(voidptr(&value))
	C.g_value_unset(voidptr(&value))
	return result
}

fn set_bool_property(obj voidptr, prop_name string, val bool) {
	mut gvalue := GValueBuffer{}
	C.g_value_init(voidptr(&gvalue), g_type_boolean_id)
	C.g_value_set_boolean(voidptr(&gvalue), val)
	C.g_object_set_property(obj, prop_name.str, voidptr(&gvalue))
	C.g_value_unset(voidptr(&gvalue))
}

fn get_i8_property(obj voidptr, prop_name string) i8 {
	mut value := GValueBuffer{}
	C.g_value_init(voidptr(&value), g_type_char_id)
	C.g_object_get_property(obj, prop_name.str, voidptr(&value))
	result := C.g_value_get_schar(voidptr(&value))
	C.g_value_unset(voidptr(&value))
	return result
}

fn set_i8_property(obj voidptr, prop_name string, val i8) {
	mut gvalue := GValueBuffer{}
	C.g_value_init(voidptr(&gvalue), g_type_char_id)
	C.g_value_set_schar(voidptr(&gvalue), val)
	C.g_object_set_property(obj, prop_name.str, voidptr(&gvalue))
	C.g_value_unset(voidptr(&gvalue))
}

fn get_u8_property(obj voidptr, prop_name string) u8 {
	mut value := GValueBuffer{}
	C.g_value_init(voidptr(&value), g_type_uchar_id)
	C.g_object_get_property(obj, prop_name.str, voidptr(&value))
	result := C.g_value_get_uchar(voidptr(&value))
	C.g_value_unset(voidptr(&value))
	return result
}

fn set_u8_property(obj voidptr, prop_name string, val u8) {
	mut gvalue := GValueBuffer{}
	C.g_value_init(voidptr(&gvalue), g_type_uchar_id)
	C.g_value_set_uchar(voidptr(&gvalue), val)
	C.g_object_set_property(obj, prop_name.str, voidptr(&gvalue))
	C.g_value_unset(voidptr(&gvalue))
}

fn get_int_property(obj voidptr, prop_name string) int {
	mut value := GValueBuffer{}
	C.g_value_init(voidptr(&value), g_type_int_id)
	C.g_object_get_property(obj, prop_name.str, voidptr(&value))
	result := C.g_value_get_int(voidptr(&value))
	C.g_value_unset(voidptr(&value))
	return result
}

fn set_int_property(obj voidptr, prop_name string, val int) {
	mut gvalue := GValueBuffer{}
	C.g_value_init(voidptr(&gvalue), g_type_int_id)
	C.g_value_set_int(voidptr(&gvalue), val)
	C.g_object_set_property(obj, prop_name.str, voidptr(&gvalue))
	C.g_value_unset(voidptr(&gvalue))
}

fn get_u32_property(obj voidptr, prop_name string) u32 {
	mut value := GValueBuffer{}
	C.g_value_init(voidptr(&value), g_type_uint_id)
	C.g_object_get_property(obj, prop_name.str, voidptr(&value))
	result := C.g_value_get_uint(voidptr(&value))
	C.g_value_unset(voidptr(&value))
	return result
}

fn set_u32_property(obj voidptr, prop_name string, val u32) {
	mut gvalue := GValueBuffer{}
	C.g_value_init(voidptr(&gvalue), g_type_uint_id)
	C.g_value_set_uint(voidptr(&gvalue), val)
	C.g_object_set_property(obj, prop_name.str, voidptr(&gvalue))
	C.g_value_unset(voidptr(&gvalue))
}

fn get_i64_property(obj voidptr, prop_name string) i64 {
	mut value := GValueBuffer{}
	C.g_value_init(voidptr(&value), g_type_int64_id)
	C.g_object_get_property(obj, prop_name.str, voidptr(&value))
	result := C.g_value_get_int64(voidptr(&value))
	C.g_value_unset(voidptr(&value))
	return result
}

fn set_i64_property(obj voidptr, prop_name string, val i64) {
	mut gvalue := GValueBuffer{}
	C.g_value_init(voidptr(&gvalue), g_type_int64_id)
	C.g_value_set_int64(voidptr(&gvalue), val)
	C.g_object_set_property(obj, prop_name.str, voidptr(&gvalue))
	C.g_value_unset(voidptr(&gvalue))
}

fn get_u64_property(obj voidptr, prop_name string) u64 {
	mut value := GValueBuffer{}
	C.g_value_init(voidptr(&value), g_type_uint64_id)
	C.g_object_get_property(obj, prop_name.str, voidptr(&value))
	result := C.g_value_get_uint64(voidptr(&value))
	C.g_value_unset(voidptr(&value))
	return result
}

fn set_u64_property(obj voidptr, prop_name string, val u64) {
	mut gvalue := GValueBuffer{}
	C.g_value_init(voidptr(&gvalue), g_type_uint64_id)
	C.g_value_set_uint64(voidptr(&gvalue), val)
	C.g_object_set_property(obj, prop_name.str, voidptr(&gvalue))
	C.g_value_unset(voidptr(&gvalue))
}

fn get_f32_property(obj voidptr, prop_name string) f32 {
	mut value := GValueBuffer{}
	C.g_value_init(voidptr(&value), g_type_float_id)
	C.g_object_get_property(obj, prop_name.str, voidptr(&value))
	result := C.g_value_get_float(voidptr(&value))
	C.g_value_unset(voidptr(&value))
	return result
}

fn set_f32_property(obj voidptr, prop_name string, val f32) {
	mut gvalue := GValueBuffer{}
	C.g_value_init(voidptr(&gvalue), g_type_float_id)
	C.g_value_set_float(voidptr(&gvalue), val)
	C.g_object_set_property(obj, prop_name.str, voidptr(&gvalue))
	C.g_value_unset(voidptr(&gvalue))
}

fn get_f64_property(obj voidptr, prop_name string) f64 {
	mut value := GValueBuffer{}
	C.g_value_init(voidptr(&value), g_type_double_id)
	C.g_object_get_property(obj, prop_name.str, voidptr(&value))
	result := C.g_value_get_double(voidptr(&value))
	C.g_value_unset(voidptr(&value))
	return result
}

fn set_f64_property(obj voidptr, prop_name string, val f64) {
	mut gvalue := GValueBuffer{}
	C.g_value_init(voidptr(&gvalue), g_type_double_id)
	C.g_value_set_double(voidptr(&gvalue), val)
	C.g_object_set_property(obj, prop_name.str, voidptr(&gvalue))
	C.g_value_unset(voidptr(&gvalue))
}

fn get_string_property(obj voidptr, prop_name string) string {
	mut value := GValueBuffer{}
	C.g_value_init(voidptr(&value), g_type_string_id)
	C.g_object_get_property(obj, prop_name.str, voidptr(&value))
	result := unsafe { cstring_to_vstring(C.g_value_get_string(voidptr(&value))) }
	C.g_value_unset(voidptr(&value))
	return result
}

fn set_string_property(obj voidptr, prop_name string, val string) {
	mut gvalue := GValueBuffer{}
	C.g_value_init(voidptr(&gvalue), g_type_string_id)
	C.g_value_set_string(voidptr(&gvalue), val.str)
	C.g_object_set_property(obj, prop_name.str, voidptr(&gvalue))
	C.g_value_unset(voidptr(&gvalue))
}

fn get_voidptr_property(obj voidptr, prop_name string) voidptr {
	mut value := GValueBuffer{}
	C.g_value_init(voidptr(&value), g_type_pointer_id)
	C.g_object_get_property(obj, prop_name.str, voidptr(&value))
	result := C.g_value_get_pointer(voidptr(&value))
	C.g_value_unset(voidptr(&value))
	return result
}

fn set_voidptr_property(obj voidptr, prop_name string, val voidptr) {
	mut gvalue := GValueBuffer{}
	C.g_value_init(voidptr(&gvalue), g_type_pointer_id)
	C.g_value_set_pointer(voidptr(&gvalue), val)
	C.g_object_set_property(obj, prop_name.str, voidptr(&gvalue))
	C.g_value_unset(voidptr(&gvalue))
}
'

	os.write_file(util_path, content) or {
		eprintln('Warning: Failed to write ${util_path}')
		return
	}
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

fn generate_c_method_declaration(method FunctionInfo) string {
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
			arg_type := get_c_type(arg.get_v_type())
			c_params << '${arg_name} ${arg_type}'
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

	// generate function signature
	return_sig := get_c_return_sig(return_v_type, skip_return)
	return if return_sig.len == 0 {
		'fn C.${symbol}(${c_params.join(', ')})\n'
	} else {
		'fn C.${symbol}(${c_params.join(', ')}) ${return_sig}\n'
	}
}


fn get_c_type(v_type string) string {
	return match v_type {
		'string' { '&char' }
		'bool' { 'bool' }
		'void', 'i8', 'u8', 'i16', 'u16', 'int', 'u32', 'i64', 'u64', 'f32', 'f64' { v_type }
		'i32' { 'int' }
		else { 'voidptr' }
	}
}

fn get_c_return_sig(v_type string, skip_return bool) string {
	return if skip_return || v_type == 'void' { '' } else { get_c_type(v_type) }
}

fn get_v_return_sig(v_type string, can_error bool, may_null bool, skip_return bool) string {
	if skip_return || v_type == 'void' {
		return if can_error { '!' } else { '' }
	}
	is_nullable_type := v_type == 'string' || v_type == 'voidptr' || v_type.starts_with('&')
	// V does not support !?T — when both can_error and may_null, use !T (nil treated as error)
	if may_null && is_nullable_type && !can_error {
		return '?${v_type}'
	}
	return if can_error { '!${v_type}' } else { v_type }
}

// generate the body of a method binding (from C call to return statement)
fn generate_method_body(symbol string, receiver string, call_args []string, return_v_type string, can_throw bool, may_null bool, skip_return bool) string {
	needs_string_conv := return_v_type == 'string'
	is_nullable_type := return_v_type == 'string' || return_v_type == 'voidptr'
		|| return_v_type.starts_with('&')
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
		} else {
			content += 'C.${symbol}(${receiver}'
		}
		if call_args.len > 0 {
			content += ', ${call_args.join(', ')}'
		}
		if can_throw {
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
	return content
}
