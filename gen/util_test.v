module gen

import os

fn test_get_vmod_path_returns_non_empty() {
	path := get_vmod_path('')
	assert path != ''
}

fn test_get_vmod_path_finds_v_mod() {
	path := get_vmod_path('v.mod')
	assert os.exists(path), 'v.mod should exist at ${path}'
}

fn test_get_vmod_path_v_mod_is_file() {
	path := get_vmod_path('v.mod')
	assert os.is_file(path), '${path} should be a file'
}

fn test_get_vmod_path_empty_string() {
	path := get_vmod_path('')
	assert os.is_dir(path), 'empty path should return module directory'
}

fn test_get_vmod_path_subdirectory() {
	// test with a file we know exists in gen/ subdirectory
	path := get_vmod_path('gen/util.v')
	assert os.exists(path), 'gen/util.v should exist at ${path}'
	assert os.is_file(path), 'gen/util.v should be a file'
}

fn test_get_vmod_path_contains_vgi() {
	// The path should contain 'vgi' since this is the vgi module
	path := get_vmod_path('')
	assert path.contains('vgi'), 'module path should contain "vgi", got: ${path}'
}

fn test_get_vmod_path_multiple_files() {
	// test that we can locate multiple known files
	files := ['v.mod', 'gen/util.v', 'gen/gi.v', 'gen/compat.c.v']
	for file in files {
		path := get_vmod_path(file)
		assert os.exists(path), '${file} should exist at ${path}'
	}
}

fn test_sanitize_param_name_keywords() {
	// V keywords should be suffixed with underscore
	assert sanitize_param_name('string') == 'string_'
	assert sanitize_param_name('type') == 'type_'
	assert sanitize_param_name('struct') == 'struct_'
	assert sanitize_param_name('return') == 'return_'
	assert sanitize_param_name('if') == 'if_'
}

fn test_sanitize_param_name_non_keywords() {
	// non-keywords should pass through unchanged
	assert sanitize_param_name('name') == 'name'
	assert sanitize_param_name('value') == 'value'
	assert sanitize_param_name('count') == 'count'
}

fn test_get_binding_dir_name() {
	assert get_binding_dir_name('Gtk', '4.0') == 'gtk_4_0'
	assert get_binding_dir_name('GLib', '2.0') == 'glib_2_0'
	assert get_binding_dir_name('cairo', '1.0') == 'cairo_1_0'
	assert get_binding_dir_name('Pango', '1.50') == 'pango_1_50'
}

fn test_get_binding_dir_name_with_hyphens() {
	assert get_binding_dir_name('Gtk-Test', '4.0') == 'gtk_test_4_0'
}

fn test_get_binding_dir_name_lowercase() {
	// library name should be lowercased
	result := get_binding_dir_name('GTK', '4.0')
	assert result == 'gtk_4_0'
	assert !result.contains('GTK')
}

fn test_get_binding_dir_name_version_periods() {
	// periods in version should become underscores
	result := get_binding_dir_name('test', '1.2.3')
	assert result == 'test_1_2_3'
	assert !result.contains('.')
}
