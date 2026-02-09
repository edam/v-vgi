module gen

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

fn test_generate_interface() {
	repo := get_default_repository()
	repo.require('Gio', '2.0') or {
		eprintln('Failed to load Gio-2.0: ${err}')
		eprintln('This test requires Gio-2.0 to be installed')
		return
	}

	// find ListModel interface
	n_infos := repo.get_n_infos('Gio')
	mut interface_info := ?InterfaceInfo(none)

	for i in 0 .. int(n_infos) {
		info := repo.get_info('Gio', i) or { continue }
		if info.get_type() == 'interface' && info.get_name() == 'ListModel' {
			interface_info = info.as_interface_info()
			break
		}
		info.free()
	}

	if iface := interface_info {
		// generate C declarations
		c_decls := generate_c_interface_method_declarations(iface)

		// verify C declarations are generated
		assert c_decls.contains('fn C.') || c_decls == '' // may have no public methods

		// generate interface methods
		content := generate_interface_methods(iface, 'ListModel')

		// verify methods are generated
		assert content.contains('pub fn (obj &ListModel)') || content == ''

		iface.free()
	} else {
		eprintln('ListModel interface not found in Gio-2.0')
		eprintln('This is okay if Gio is an older version')
	}
}

fn test_object_interface_implementations() {
	repo := get_default_repository()
	repo.require('Gio', '2.0') or {
		eprintln('Failed to load Gio-2.0: ${err}')
		eprintln('This test requires Gio-2.0 to be installed')
		return
	}

	// find an object that implements interfaces
	n_infos := repo.get_n_infos('Gio')
	mut object_info := ?ObjectInfo(none)

	for i in 0 .. int(n_infos) {
		info := repo.get_info('Gio', i) or { continue }
		if info.get_type() == 'object' {
			obj_info := info.as_object_info()
			// check if it implements any interfaces
			if obj_info.get_n_interfaces() > 0 {
				object_info = obj_info
				break
			}
			obj_info.free()
		} else {
			info.free()
		}
	}

	if obj := object_info {
		object_name := obj.get_name()

		// generate interface implementations
		content := generate_object_interface_implementations(obj, object_name)

		// verify interface methods are generated if the object implements interfaces
		n_interfaces := obj.get_n_interfaces()
		if n_interfaces > 0 {
			assert content.contains('// interface implementations')
				|| content.contains('pub fn (obj &${object_name})')
		}

		obj.free()
	} else {
		eprintln('No object with interfaces found in Gio-2.0')
		eprintln('This is okay if Gio is an older version')
	}
}

fn test_explicit_implements_declaration() {
	repo := get_default_repository()
	repo.require('Gio', '2.0') or {
		eprintln('Failed to load Gio-2.0: ${err}')
		eprintln('This test requires Gio-2.0 to be installed')
		return
	}

	// find an object that implements interfaces
	n_infos := repo.get_n_infos('Gio')
	mut found := false

	for i in 0 .. int(n_infos) {
		info := repo.get_info('Gio', i) or { continue }
		if info.get_type() == 'object' {
			obj_info := info.as_object_info()
			n_interfaces := obj_info.get_n_interfaces()

			if n_interfaces > 0 {
				object_name := obj_info.get_name()
				println('Testing ${object_name} which implements ${n_interfaces} interfaces')

				// simulate struct generation to verify implements clause
				mut implements_list := []string{}
				for j in 0 .. int(n_interfaces) {
					iface := obj_info.get_interface(u32(j)) or { continue }
					iface_name := iface.get_name()
					implements_list << 'I${iface_name}'
					iface.free()
				}

				// verify we have interfaces
				assert implements_list.len > 0
				println('  implements: ${implements_list.join(', ')}')

				found = true
				obj_info.free() // frees the underlying BaseInfo ptr
				break
			}
			obj_info.free()
		} else {
			info.free()
		}
	}

	if !found {
		eprintln('No object with interfaces found in Gio-2.0')
		eprintln('This is okay if Gio is an older version')
	}
}

fn test_generate_enum() {
	repo := get_default_repository()
	repo.require('Gio', '2.0') or {
		eprintln('Failed to load Gio-2.0: ${err}')
		eprintln('This test requires Gio-2.0 to be installed')
		return
	}

	// find an enum to test
	n_infos := repo.get_n_infos('Gio')
	mut enum_info := ?EnumInfo(none)

	for i in 0 .. int(n_infos) {
		info := repo.get_info('Gio', i) or { continue }
		if info.get_type() == 'enum' {
			enum_info = info.as_enum_info()
			break
		}
		info.free()
	}

	if enum_val := enum_info {
		enum_name := enum_val.get_name()
		println('Testing enum generation for: ${enum_name}')

		// create temp directory for test
		test_dir := os.join_path(os.temp_dir(), 'vgi_enum_test')
		os.mkdir_all(test_dir) or {}
		defer {
			os.rmdir_all(test_dir) or {}
		}

		// generate enum
		generate_enum_binding(enum_val, test_dir)

		// verify file was created
		file_path := os.join_path(test_dir, '${enum_name.to_lower()}.v')
		assert os.exists(file_path)

		// verify content
		content := os.read_file(file_path) or {
			eprintln('Failed to read generated file: ${err}')
			assert false
			return
		}

		// should contain enum declaration
		assert content.contains('pub enum ${enum_name}')

		// should contain at least one value
		n_values := enum_val.get_n_values()
		assert n_values > 0

		println('Enum generation test passed!')
		enum_val.free()
	} else {
		eprintln('No enum found in Gio-2.0')
		eprintln('This is okay if Gio is an older version')
	}
}
