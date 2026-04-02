module gen

import os

pub fn get_vmod_path(rel_path string) string {
	// @FILE is in gen/ subdirectory, go up one level to module root
	gen_dir := os.dir(@FILE)
	vmod_path := os.dir(gen_dir)
	return os.join_path(vmod_path, rel_path)
}

const v_keywords = ['string', 'type', 'struct', 'enum', 'interface', 'fn', 'const', 'import',
	'module', 'pub', 'mut', 'shared', 'static', 'volatile', 'unsafe', 'return', 'if', 'else', 'for',
	'match', 'select', 'defer', 'goto', 'break', 'continue', 'in', 'is', 'as', 'or', 'and', 'not',
	'none', 'true', 'false', 'nil', 'sizeof', 'typeof', 'isreftype', 'offsetof', 'dump', 'assert',
	'map', 'chan', 'lock', 'rlock', 'go', 'spawn', 'asm', '__global', '__offsetof', 'error', 'panic',
	'exit', 'print', 'println', 'eprint', 'eprintln']

// convert parameter names that conflict with V keywords
pub fn sanitize_param_name(name string) string {
	return if name in v_keywords { '${name}_' } else { name }
}

struct LibraryCInfo {
	pkg_config string
	include    string
}

fn library_c_info_map() map[string]LibraryCInfo {
	return {
		'glib':       LibraryCInfo{'glib-2.0', '<glib.h>'}
		'gobject':    LibraryCInfo{'gobject-2.0', '<glib-object.h>'}
		'gio':        LibraryCInfo{'gio-2.0', '<gio/gio.h>'}
		'pango':      LibraryCInfo{'pango', '<pango/pango.h>'}
		'pangocairo': LibraryCInfo{'pangocairo', '<pango/pangocairo.h>'}
		'cairo':      LibraryCInfo{'cairo', '<cairo.h>'}
		'atk':        LibraryCInfo{'atk', '<atk/atk.h>'}
		'gdk-pixbuf': LibraryCInfo{'gdk-pixbuf-2.0', '<gdk-pixbuf/gdk-pixbuf.h>'}
		'gdkpixbuf':  LibraryCInfo{'gdk-pixbuf-2.0', '<gdk-pixbuf/gdk-pixbuf.h>'}
		'gmodule':    LibraryCInfo{'gmodule-2.0', '<glib.h>'}
		'gthread':    LibraryCInfo{'gthread-2.0', '<glib.h>'}
	}
}

// return pkg-config name and include path for a library
fn get_library_c_info(library string, version string) (string, string) {
	lib_lower := library.to_lower()
	version_parts := version.split('.')
	version_major := if version_parts.len > 0 { version_parts[0] } else { '' }

	// gtk and gdk have version-dependent pkg-config names
	if lib_lower == 'gtk' {
		if version_major == '3' {
			return 'gtk+-3.0', '<gtk/gtk.h>'
		}
		return 'gtk4', '<gtk/gtk.h>'
	}
	if lib_lower == 'gdk' {
		if version_major == '3' {
			return 'gdk-3.0', '<gdk/gdk.h>'
		}
		return 'gtk4', '<gdk/gdk.h>'
	}

	info_map := library_c_info_map()
	if info := info_map[lib_lower] {
		return info.pkg_config, info.include
	}

	// fallback: use library-version for pkg-config and library/library.h for include
	pkgconfig_name := '${lib_lower}-${version}'
	include_path := '<${lib_lower}/${lib_lower}.h>'
	return pkgconfig_name, include_path
}

// platform/backend-specific terms that may indicate a symbol isn't available on all platforms
const platform_hints = ['unix', 'win32', 'wayland', 'x11', 'quartz', 'broadway', 'mir']

// return true if the C symbol is available in the currently loaded shared libraries.
// only call this when the symbol name contains a platform hint (see platform_hints).
fn symbol_exists(name string) bool {
	$if windows {
		sym := C.GetProcAddress(C.GetModuleHandleA(unsafe { nil }), name.str)
		return sym != unsafe { nil }
	} $else {
		sym := C.dlsym(unsafe { nil }, name.str)
		// if sym == unsafe { nil } {
		// 	println('symbol not found in library, skipping: ${name}')
		// }
		return sym != unsafe { nil }
	}
}

// return true if the symbol name contains a platform-specific term and the symbol
// is not found in the loaded shared libraries — i.e. it should be skipped.
fn symbol_unavailable(symbol string) bool {
	s := symbol.to_lower()
	for hint in platform_hints {
		if s.contains(hint) {
			return !symbol_exists(symbol)
		}
	}
	return false
}

// convert library name and version to directory name
// e.g., "Gtk-4.0" becomes "gtk_4_0"
pub fn get_binding_dir_name(library string, version string) string {
	lib_lower := library.to_lower().replace('-', '_')
	ver_lower := version.replace('.', '_').replace('-', '_')
	return '${lib_lower}_${ver_lower}'
}
