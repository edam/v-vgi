module gen

import os

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

// generate C interop file with pkgconfig and includes
fn generate_compat_c(binding_dir string, library string, version string) {
	compat_path := os.join_path(binding_dir, 'compat.c.v')
	module_name := os.file_name(binding_dir)

	pkgconfig_name, include_path := get_library_c_info(library, version)

	content := 'module ${module_name}

#pkgconfig ${pkgconfig_name}
#include ${include_path}

// C declarations for GObject/GLib functions using voidptr to avoid cross-module type conflicts
fn C.g_object_new_with_properties(object_type u64, n_properties u32, names &&char, values voidptr) voidptr
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
