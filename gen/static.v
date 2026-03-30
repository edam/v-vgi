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
fn C.g_signal_connect_data(instance voidptr, detailed_signal &char, c_handler voidptr, data voidptr, destroy_data voidptr, connect_flags int) u64
fn C.g_signal_handler_disconnect(instance voidptr, handler_id u64)

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

// helper functions for appending GValue pairs to arrays (used in constructors)

fn v_gv_bool(mut names []&char, mut values []GValueBuffer, name &char, value bool) {
	names << name
	mut gv := GValueBuffer{}
	C.g_value_init(voidptr(&gv), g_type_boolean_id)
	C.g_value_set_boolean(voidptr(&gv), value)
	values << gv
}

fn v_gv_i8(mut names []&char, mut values []GValueBuffer, name &char, value i8) {
	names << name
	mut gv := GValueBuffer{}
	C.g_value_init(voidptr(&gv), g_type_char_id)
	C.g_value_set_schar(voidptr(&gv), value)
	values << gv
}

fn v_gv_u8(mut names []&char, mut values []GValueBuffer, name &char, value u8) {
	names << name
	mut gv := GValueBuffer{}
	C.g_value_init(voidptr(&gv), g_type_uchar_id)
	C.g_value_set_uchar(voidptr(&gv), value)
	values << gv
}

fn v_gv_int(mut names []&char, mut values []GValueBuffer, name &char, value int) {
	names << name
	mut gv := GValueBuffer{}
	C.g_value_init(voidptr(&gv), g_type_int_id)
	C.g_value_set_int(voidptr(&gv), value)
	values << gv
}

fn v_gv_u32(mut names []&char, mut values []GValueBuffer, name &char, value u32) {
	names << name
	mut gv := GValueBuffer{}
	C.g_value_init(voidptr(&gv), g_type_uint_id)
	C.g_value_set_uint(voidptr(&gv), value)
	values << gv
}

fn v_gv_i64(mut names []&char, mut values []GValueBuffer, name &char, value i64) {
	names << name
	mut gv := GValueBuffer{}
	C.g_value_init(voidptr(&gv), g_type_int64_id)
	C.g_value_set_int64(voidptr(&gv), value)
	values << gv
}

fn v_gv_u64(mut names []&char, mut values []GValueBuffer, name &char, value u64) {
	names << name
	mut gv := GValueBuffer{}
	C.g_value_init(voidptr(&gv), g_type_uint64_id)
	C.g_value_set_uint64(voidptr(&gv), value)
	values << gv
}

fn v_gv_f32(mut names []&char, mut values []GValueBuffer, name &char, value f32) {
	names << name
	mut gv := GValueBuffer{}
	C.g_value_init(voidptr(&gv), g_type_float_id)
	C.g_value_set_float(voidptr(&gv), value)
	values << gv
}

fn v_gv_f64(mut names []&char, mut values []GValueBuffer, name &char, value f64) {
	names << name
	mut gv := GValueBuffer{}
	C.g_value_init(voidptr(&gv), g_type_double_id)
	C.g_value_set_double(voidptr(&gv), value)
	values << gv
}

fn v_gv_string(mut names []&char, mut values []GValueBuffer, name &char, value string) {
	names << name
	mut gv := GValueBuffer{}
	C.g_value_init(voidptr(&gv), g_type_string_id)
	C.g_value_set_string(voidptr(&gv), value.str)
	values << gv
}

fn v_gv_voidptr(mut names []&char, mut values []GValueBuffer, name &char, value voidptr) {
	names << name
	mut gv := GValueBuffer{}
	C.g_value_init(voidptr(&gv), g_type_pointer_id)
	C.g_value_set_pointer(voidptr(&gv), value)
	values << gv
}

// helper functions for property access

fn v_getp_bool(obj voidptr, prop_name string) bool {
	mut value := GValueBuffer{}
	C.g_value_init(voidptr(&value), g_type_boolean_id)
	C.g_object_get_property(obj, prop_name.str, voidptr(&value))
	result := C.g_value_get_boolean(voidptr(&value))
	C.g_value_unset(voidptr(&value))
	return result
}

fn v_setp_bool(obj voidptr, prop_name string, val bool) {
	mut gvalue := GValueBuffer{}
	C.g_value_init(voidptr(&gvalue), g_type_boolean_id)
	C.g_value_set_boolean(voidptr(&gvalue), val)
	C.g_object_set_property(obj, prop_name.str, voidptr(&gvalue))
	C.g_value_unset(voidptr(&gvalue))
}

fn v_getp_i8(obj voidptr, prop_name string) i8 {
	mut value := GValueBuffer{}
	C.g_value_init(voidptr(&value), g_type_char_id)
	C.g_object_get_property(obj, prop_name.str, voidptr(&value))
	result := C.g_value_get_schar(voidptr(&value))
	C.g_value_unset(voidptr(&value))
	return result
}

fn v_setp_i8(obj voidptr, prop_name string, val i8) {
	mut gvalue := GValueBuffer{}
	C.g_value_init(voidptr(&gvalue), g_type_char_id)
	C.g_value_set_schar(voidptr(&gvalue), val)
	C.g_object_set_property(obj, prop_name.str, voidptr(&gvalue))
	C.g_value_unset(voidptr(&gvalue))
}

fn v_getp_u8(obj voidptr, prop_name string) u8 {
	mut value := GValueBuffer{}
	C.g_value_init(voidptr(&value), g_type_uchar_id)
	C.g_object_get_property(obj, prop_name.str, voidptr(&value))
	result := C.g_value_get_uchar(voidptr(&value))
	C.g_value_unset(voidptr(&value))
	return result
}

fn v_setp_u8(obj voidptr, prop_name string, val u8) {
	mut gvalue := GValueBuffer{}
	C.g_value_init(voidptr(&gvalue), g_type_uchar_id)
	C.g_value_set_uchar(voidptr(&gvalue), val)
	C.g_object_set_property(obj, prop_name.str, voidptr(&gvalue))
	C.g_value_unset(voidptr(&gvalue))
}

fn v_getp_int(obj voidptr, prop_name string) int {
	mut value := GValueBuffer{}
	C.g_value_init(voidptr(&value), g_type_int_id)
	C.g_object_get_property(obj, prop_name.str, voidptr(&value))
	result := C.g_value_get_int(voidptr(&value))
	C.g_value_unset(voidptr(&value))
	return result
}

fn v_setp_int(obj voidptr, prop_name string, val int) {
	mut gvalue := GValueBuffer{}
	C.g_value_init(voidptr(&gvalue), g_type_int_id)
	C.g_value_set_int(voidptr(&gvalue), val)
	C.g_object_set_property(obj, prop_name.str, voidptr(&gvalue))
	C.g_value_unset(voidptr(&gvalue))
}

fn v_getp_u32(obj voidptr, prop_name string) u32 {
	mut value := GValueBuffer{}
	C.g_value_init(voidptr(&value), g_type_uint_id)
	C.g_object_get_property(obj, prop_name.str, voidptr(&value))
	result := C.g_value_get_uint(voidptr(&value))
	C.g_value_unset(voidptr(&value))
	return result
}

fn v_setp_u32(obj voidptr, prop_name string, val u32) {
	mut gvalue := GValueBuffer{}
	C.g_value_init(voidptr(&gvalue), g_type_uint_id)
	C.g_value_set_uint(voidptr(&gvalue), val)
	C.g_object_set_property(obj, prop_name.str, voidptr(&gvalue))
	C.g_value_unset(voidptr(&gvalue))
}

fn v_getp_i64(obj voidptr, prop_name string) i64 {
	mut value := GValueBuffer{}
	C.g_value_init(voidptr(&value), g_type_int64_id)
	C.g_object_get_property(obj, prop_name.str, voidptr(&value))
	result := C.g_value_get_int64(voidptr(&value))
	C.g_value_unset(voidptr(&value))
	return result
}

fn v_setp_i64(obj voidptr, prop_name string, val i64) {
	mut gvalue := GValueBuffer{}
	C.g_value_init(voidptr(&gvalue), g_type_int64_id)
	C.g_value_set_int64(voidptr(&gvalue), val)
	C.g_object_set_property(obj, prop_name.str, voidptr(&gvalue))
	C.g_value_unset(voidptr(&gvalue))
}

fn v_getp_u64(obj voidptr, prop_name string) u64 {
	mut value := GValueBuffer{}
	C.g_value_init(voidptr(&value), g_type_uint64_id)
	C.g_object_get_property(obj, prop_name.str, voidptr(&value))
	result := C.g_value_get_uint64(voidptr(&value))
	C.g_value_unset(voidptr(&value))
	return result
}

fn v_setp_u64(obj voidptr, prop_name string, val u64) {
	mut gvalue := GValueBuffer{}
	C.g_value_init(voidptr(&gvalue), g_type_uint64_id)
	C.g_value_set_uint64(voidptr(&gvalue), val)
	C.g_object_set_property(obj, prop_name.str, voidptr(&gvalue))
	C.g_value_unset(voidptr(&gvalue))
}

fn v_getp_f32(obj voidptr, prop_name string) f32 {
	mut value := GValueBuffer{}
	C.g_value_init(voidptr(&value), g_type_float_id)
	C.g_object_get_property(obj, prop_name.str, voidptr(&value))
	result := C.g_value_get_float(voidptr(&value))
	C.g_value_unset(voidptr(&value))
	return result
}

fn v_setp_f32(obj voidptr, prop_name string, val f32) {
	mut gvalue := GValueBuffer{}
	C.g_value_init(voidptr(&gvalue), g_type_float_id)
	C.g_value_set_float(voidptr(&gvalue), val)
	C.g_object_set_property(obj, prop_name.str, voidptr(&gvalue))
	C.g_value_unset(voidptr(&gvalue))
}

fn v_getp_f64(obj voidptr, prop_name string) f64 {
	mut value := GValueBuffer{}
	C.g_value_init(voidptr(&value), g_type_double_id)
	C.g_object_get_property(obj, prop_name.str, voidptr(&value))
	result := C.g_value_get_double(voidptr(&value))
	C.g_value_unset(voidptr(&value))
	return result
}

fn v_setp_f64(obj voidptr, prop_name string, val f64) {
	mut gvalue := GValueBuffer{}
	C.g_value_init(voidptr(&gvalue), g_type_double_id)
	C.g_value_set_double(voidptr(&gvalue), val)
	C.g_object_set_property(obj, prop_name.str, voidptr(&gvalue))
	C.g_value_unset(voidptr(&gvalue))
}

fn v_getp_string(obj voidptr, prop_name string) string {
	mut value := GValueBuffer{}
	C.g_value_init(voidptr(&value), g_type_string_id)
	C.g_object_get_property(obj, prop_name.str, voidptr(&value))
	result := unsafe { cstring_to_vstring(C.g_value_get_string(voidptr(&value))) }
	C.g_value_unset(voidptr(&value))
	return result
}

fn v_setp_string(obj voidptr, prop_name string, val string) {
	mut gvalue := GValueBuffer{}
	C.g_value_init(voidptr(&gvalue), g_type_string_id)
	C.g_value_set_string(voidptr(&gvalue), val.str)
	C.g_object_set_property(obj, prop_name.str, voidptr(&gvalue))
	C.g_value_unset(voidptr(&gvalue))
}

fn v_getp_voidptr(obj voidptr, prop_name string) voidptr {
	mut value := GValueBuffer{}
	C.g_value_init(voidptr(&value), g_type_pointer_id)
	C.g_object_get_property(obj, prop_name.str, voidptr(&value))
	result := C.g_value_get_pointer(voidptr(&value))
	C.g_value_unset(voidptr(&value))
	return result
}

fn v_setp_voidptr(obj voidptr, prop_name string, val voidptr) {
	mut gvalue := GValueBuffer{}
	C.g_value_init(voidptr(&gvalue), g_type_pointer_id)
	C.g_value_set_pointer(voidptr(&gvalue), val)
	C.g_object_set_property(obj, prop_name.str, voidptr(&gvalue))
	C.g_value_unset(voidptr(&gvalue))
}

// Signal closure infrastructure.
// connect_<signal> methods box a V closure and register a trampoline as the C callback.
// GLib calls the trampoline with (sender, ...extra_params..., user_data); the trampoline
// ignores everything except user_data, which holds the boxed V closure.

struct VSignalVoidClosure {
	call fn() @[required]
}

struct VSignalBoolClosure {
	call fn() bool @[required]
}

// destroy notify: frees the closure box when GLib disconnects the signal
fn v_closure_notify(data voidptr, _closure voidptr) {
	unsafe { free(data) }
}

// trampolines: void return, 0-3 extra C parameters (ignored)
fn v_trampoline_v0(_sender voidptr, user_data voidptr) {
	box := unsafe { &VSignalVoidClosure(user_data) }
	box.call()
}

fn v_trampoline_v1(_sender voidptr, _p1 voidptr, user_data voidptr) {
	box := unsafe { &VSignalVoidClosure(user_data) }
	box.call()
}

fn v_trampoline_v2(_sender voidptr, _p1 voidptr, _p2 voidptr, user_data voidptr) {
	box := unsafe { &VSignalVoidClosure(user_data) }
	box.call()
}

fn v_trampoline_v3(_sender voidptr, _p1 voidptr, _p2 voidptr, _p3 voidptr, user_data voidptr) {
	box := unsafe { &VSignalVoidClosure(user_data) }
	box.call()
}

fn v_trampoline_v4(_sender voidptr, _p1 voidptr, _p2 voidptr, _p3 voidptr, _p4 voidptr, user_data voidptr) {
	box := unsafe { &VSignalVoidClosure(user_data) }
	box.call()
}

fn v_trampoline_v5(_sender voidptr, _p1 voidptr, _p2 voidptr, _p3 voidptr, _p4 voidptr, _p5 voidptr, user_data voidptr) {
	box := unsafe { &VSignalVoidClosure(user_data) }
	box.call()
}

// trampolines: bool return, 0-4 extra C parameters (ignored)
fn v_trampoline_b0(_sender voidptr, user_data voidptr) bool {
	box := unsafe { &VSignalBoolClosure(user_data) }
	return box.call()
}

fn v_trampoline_b1(_sender voidptr, _p1 voidptr, user_data voidptr) bool {
	box := unsafe { &VSignalBoolClosure(user_data) }
	return box.call()
}

fn v_trampoline_b2(_sender voidptr, _p1 voidptr, _p2 voidptr, user_data voidptr) bool {
	box := unsafe { &VSignalBoolClosure(user_data) }
	return box.call()
}

fn v_trampoline_b3(_sender voidptr, _p1 voidptr, _p2 voidptr, _p3 voidptr, user_data voidptr) bool {
	box := unsafe { &VSignalBoolClosure(user_data) }
	return box.call()
}

fn v_trampoline_b4(_sender voidptr, _p1 voidptr, _p2 voidptr, _p3 voidptr, _p4 voidptr, user_data voidptr) bool {
	box := unsafe { &VSignalBoolClosure(user_data) }
	return box.call()
}
'

	os.write_file(util_path, content) or {
		eprintln('Warning: Failed to write ${util_path}')
		return
	}
}
