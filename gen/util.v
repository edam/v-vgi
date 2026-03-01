module gen

import os

pub fn get_vmod_path(rel_path string) string {
	// @FILE is in gen/ subdirectory, go up one level to module root
	gen_dir := os.dir(@FILE)
	vmod_path := os.dir(gen_dir)
	return os.join_path(vmod_path, rel_path)
}

// convert parameter names that conflict with V keywords
pub fn sanitize_param_name(name string) string {
	return match name {
		'string', 'type', 'struct', 'enum', 'interface', 'fn', 'const',
		'import', 'module', 'pub', 'mut', 'shared', 'static', 'volatile',
		'unsafe', 'return', 'if', 'else', 'for', 'match', 'select',
		'defer', 'goto', 'break', 'continue', 'in', 'is', 'as', 'or',
		'and', 'not', 'none', 'true', 'false', 'nil', 'sizeof', 'typeof',
		'isreftype', 'offsetof', 'dump', 'assert', 'map', 'chan', 'lock',
		'rlock', 'go', 'spawn', 'asm', '__global', '__offsetof' {
			'${name}_'
		}
		else {
			name
		}
	}
}

// convert library name and version to directory name
// e.g., "Gtk-4.0" becomes "gtk_4_0"
pub fn get_binding_dir_name(library string, version string) string {
	lib_lower := library.to_lower().replace('-', '_')
	ver_lower := version.replace('.', '_').replace('-', '_')
	return '${lib_lower}_${ver_lower}'
}
