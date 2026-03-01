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

fn C.g_type_boolean() u64
fn C.g_type_int() u64
fn C.g_type_uint() u64
fn C.g_type_int64() u64
fn C.g_type_uint64() u64
fn C.g_type_float() u64
fn C.g_type_double() u64
fn C.g_type_string() u64
fn C.g_type_pointer() u64
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

// GValue is a C struct we need to allocate. size based on GValue definition (24 bytes on most systems)
struct GValueBuffer {
	data [24]u8
}

// helper functions for property access

fn get_bool_property(obj voidptr, prop_name string) bool {
	mut value := GValueBuffer{}
	C.g_value_init(&value, C.g_type_boolean())
	C.g_object_get_property(obj, prop_name.str, &value)
	result := C.g_value_get_boolean(&value)
	C.g_value_unset(&value)
	return result
}

fn set_bool_property(obj voidptr, prop_name string, val bool) {
	mut gvalue := GValueBuffer{}
	C.g_value_init(&gvalue, C.g_type_boolean())
	C.g_value_set_boolean(&gvalue, val)
	C.g_object_set_property(obj, prop_name.str, &gvalue)
	C.g_value_unset(&gvalue)
}

fn get_int_property(obj voidptr, prop_name string) int {
	mut value := GValueBuffer{}
	C.g_value_init(&value, C.g_type_int())
	C.g_object_get_property(obj, prop_name.str, &value)
	result := C.g_value_get_int(&value)
	C.g_value_unset(&value)
	return result
}

fn set_int_property(obj voidptr, prop_name string, val int) {
	mut gvalue := GValueBuffer{}
	C.g_value_init(&gvalue, C.g_type_int())
	C.g_value_set_int(&gvalue, val)
	C.g_object_set_property(obj, prop_name.str, &gvalue)
	C.g_value_unset(&gvalue)
}

fn get_uint_property(obj voidptr, prop_name string) u32 {
	mut value := GValueBuffer{}
	C.g_value_init(&value, C.g_type_uint())
	C.g_object_get_property(obj, prop_name.str, &value)
	result := C.g_value_get_uint(&value)
	C.g_value_unset(&value)
	return result
}

fn set_uint_property(obj voidptr, prop_name string, val u32) {
	mut gvalue := GValueBuffer{}
	C.g_value_init(&gvalue, C.g_type_uint())
	C.g_value_set_uint(&gvalue, val)
	C.g_object_set_property(obj, prop_name.str, &gvalue)
	C.g_value_unset(&gvalue)
}

fn get_int64_property(obj voidptr, prop_name string) i64 {
	mut value := GValueBuffer{}
	C.g_value_init(&value, C.g_type_int64())
	C.g_object_get_property(obj, prop_name.str, &value)
	result := C.g_value_get_int64(&value)
	C.g_value_unset(&value)
	return result
}

fn set_int64_property(obj voidptr, prop_name string, val i64) {
	mut gvalue := GValueBuffer{}
	C.g_value_init(&gvalue, C.g_type_int64())
	C.g_value_set_int64(&gvalue, val)
	C.g_object_set_property(obj, prop_name.str, &gvalue)
	C.g_value_unset(&gvalue)
}

fn get_uint64_property(obj voidptr, prop_name string) u64 {
	mut value := GValueBuffer{}
	C.g_value_init(&value, C.g_type_uint64())
	C.g_object_get_property(obj, prop_name.str, &value)
	result := C.g_value_get_uint64(&value)
	C.g_value_unset(&value)
	return result
}

fn set_uint64_property(obj voidptr, prop_name string, val u64) {
	mut gvalue := GValueBuffer{}
	C.g_value_init(&gvalue, C.g_type_uint64())
	C.g_value_set_uint64(&gvalue, val)
	C.g_object_set_property(obj, prop_name.str, &gvalue)
	C.g_value_unset(&gvalue)
}

fn get_float_property(obj voidptr, prop_name string) f32 {
	mut value := GValueBuffer{}
	C.g_value_init(&value, C.g_type_float())
	C.g_object_get_property(obj, prop_name.str, &value)
	result := C.g_value_get_float(&value)
	C.g_value_unset(&value)
	return result
}

fn set_float_property(obj voidptr, prop_name string, val f32) {
	mut gvalue := GValueBuffer{}
	C.g_value_init(&gvalue, C.g_type_float())
	C.g_value_set_float(&gvalue, val)
	C.g_object_set_property(obj, prop_name.str, &gvalue)
	C.g_value_unset(&gvalue)
}

fn get_double_property(obj voidptr, prop_name string) f64 {
	mut value := GValueBuffer{}
	C.g_value_init(&value, C.g_type_double())
	C.g_object_get_property(obj, prop_name.str, &value)
	result := C.g_value_get_double(&value)
	C.g_value_unset(&value)
	return result
}

fn set_double_property(obj voidptr, prop_name string, val f64) {
	mut gvalue := GValueBuffer{}
	C.g_value_init(&gvalue, C.g_type_double())
	C.g_value_set_double(&gvalue, val)
	C.g_object_set_property(obj, prop_name.str, &gvalue)
	C.g_value_unset(&gvalue)
}

fn get_string_property(obj voidptr, prop_name string) string {
	mut value := GValueBuffer{}
	C.g_value_init(&value, C.g_type_string())
	C.g_object_get_property(obj, prop_name.str, &value)
	result := unsafe { cstring_to_vstring(C.g_value_get_string(&value)) }
	C.g_value_unset(&value)
	return result
}

fn set_string_property(obj voidptr, prop_name string, val string) {
	mut gvalue := GValueBuffer{}
	C.g_value_init(&gvalue, C.g_type_string())
	C.g_value_set_string(&gvalue, val.str)
	C.g_object_set_property(obj, prop_name.str, &gvalue)
	C.g_value_unset(&gvalue)
}

fn get_pointer_property(obj voidptr, prop_name string) voidptr {
	mut value := GValueBuffer{}
	C.g_value_init(&value, C.g_type_pointer())
	C.g_object_get_property(obj, prop_name.str, &value)
	result := C.g_value_get_pointer(&value)
	C.g_value_unset(&value)
	return result
}

fn set_pointer_property(obj voidptr, prop_name string, val voidptr) {
	mut gvalue := GValueBuffer{}
	C.g_value_init(&gvalue, C.g_type_pointer())
	C.g_value_set_pointer(&gvalue, val)
	C.g_object_set_property(obj, prop_name.str, &gvalue)
	C.g_value_unset(&gvalue)
}
'

	os.write_file(util_path, content) or {
		eprintln('Warning: Failed to write ${util_path}')
		return
	}
}
