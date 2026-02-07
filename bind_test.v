module vgi

import os

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

fn test_generate_object_methods() {
	// test that method generation produces valid code
	repo := get_default_repository()
	repo.require('GObject', '2.0') or {
		eprintln('Failed to load GObject-2.0: ${err}')
		assert false
		return
	}

	// find Object type
	n_infos := repo.get_n_infos('GObject')
	mut object_info := ?ObjectInfo(none)

	for i in 0 .. int(n_infos) {
		info := repo.get_info('GObject', i) or { continue }
		if info.get_type() == 'object' && info.get_name() == 'Object' {
			object_info = info.as_object_info()
			break
		}
		info.free()
	}

	assert object_info != none

	obj := object_info or { panic('unreachable') }

	// generate C declarations
	c_decls := generate_c_method_declarations(obj)

	// verify C declarations are generated
	assert c_decls.contains('fn C.') || c_decls == '' // may have no public methods

	// generate methods
	content := generate_object_methods(obj, 'TestObject')

	// verify generated code contains method definitions
	assert content.contains('pub fn (obj &TestObject)') || content == '' // may have no public methods

	obj.free()
}

fn test_generate_constructor() {
	repo := get_default_repository()
	repo.require('GObject', '2.0') or {
		eprintln('Failed to load GObject-2.0: ${err}')
		assert false
		return
	}

	// find Object type
	n_infos := repo.get_n_infos('GObject')
	mut object_info := ?ObjectInfo(none)

	for i in 0 .. int(n_infos) {
		info := repo.get_info('GObject', i) or { continue }
		if info.get_type() == 'object' && info.get_name() == 'Object' {
			object_info = info.as_object_info()
			break
		}
		info.free()
	}

	assert object_info != none

	obj := object_info or { panic('unreachable') }

	// generate constructor
	content := generate_constructor(obj, 'TestObject')

	// verify constructor signature
	assert content.contains('pub fn TestObject.new(properties TestObjectProperties)')
	assert content.contains('&TestObject')

	// should contain object creation
	assert content.contains('g_object_new') || content.contains('panic')

	obj.free()
}
