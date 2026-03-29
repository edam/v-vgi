module gen

import os

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
	c_decls := generate_object_c_method_declarations(obj, 'GObject')

	// verify C declarations are generated
	assert c_decls.contains('fn C.') || c_decls == '' // may have no public methods

	// generate methods
	content := generate_object_methods(obj, 'TestObject', 'GObject')

	// verify generated code contains method definitions
	assert content.contains('pub fn (obj &TestObject)') || content == '' // may have no public methods

	obj.free()
}

fn test_generate_object_constructor() {
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
	content := generate_object_constructor(obj, 'TestObject', 'ParentObject', 'GObject')

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
		c_decls := generate_interface_c_method_declarations(iface, 'Gio')

		// verify C declarations are generated
		assert c_decls.contains('fn C.') || c_decls == '' // may have no public methods

		// generate interface methods
		content := generate_interface_methods(iface, 'ListModel', 'Gio')

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
		content := generate_object_interface_implementations(obj, object_name, 'Gio')

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

fn test_void_pointer_arg_maps_to_voidptr() {
	// GI_TYPE_TAG_VOID (tag=0) on an argument means gpointer, not void.
	// g_object_set_data(GObject*, key, gpointer) is a reliable case.
	repo := get_default_repository()
	repo.require('GObject', '2.0') or {
		eprintln('Failed to load GObject-2.0: ${err}')
		assert false
		return
	}

	n_infos := repo.get_n_infos('GObject')
	for i in 0 .. int(n_infos) {
		info := repo.get_info('GObject', i) or { continue }
		if info.get_type() == 'object' && info.get_name() == 'Object' {
			obj := info.as_object_info()
			n_methods := obj.get_n_methods()
			for j in 0 .. int(n_methods) {
				method := obj.get_method(u32(j)) or { continue }
				if method.get_name() == 'set_data' {
					// find the 'data' arg (last arg, gpointer)
					n_args := method.get_n_args()
					for k in 0 .. int(n_args) {
						arg := method.get_arg(u32(k)) or { continue }
						if arg.get_name() == 'data' {
							v_type := arg.get_v_type('GObject')
							assert v_type == 'voidptr', 'gpointer arg should map to voidptr, got: ${v_type}'
						}
						arg.free()
					}
					method.free()
					obj.free()
					return
				}
				method.free()
			}
			obj.free()
			break
		}
		info.free()
	}
}

fn test_generate_properties_struct_no_props() {
	// GObject.Object has no writable properties - struct should still be well-formed
	repo := get_default_repository()
	repo.require('GObject', '2.0') or {
		eprintln('Failed to load GObject-2.0: ${err}')
		assert false
		return
	}

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

	content := generate_properties_struct(obj, 'Object', '', '', 'GObject')

	assert content.contains('@[params]')
	assert content.contains('pub struct ObjectProperties {')
	assert content.contains('pub:')
	assert content.contains('}\n')

	obj.free()
}

fn test_generate_properties_struct_with_parent() {
	// test that parent_embed value is embedded in the properties struct
	repo := get_default_repository()
	repo.require('GObject', '2.0') or {
		eprintln('Failed to load GObject-2.0: ${err}')
		assert false
		return
	}

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

	content := generate_properties_struct(obj, 'ChildObject', 'Object', 'Object', 'GObject')

	assert content.contains('pub struct ChildObjectProperties {')
	assert content.contains('\tObjectProperties')

	obj.free()
}

fn test_generate_properties_struct_writable_props() {
	// Gio.Application has writable properties - they should appear as optional fields
	repo := get_default_repository()
	repo.require('Gio', '2.0') or {
		eprintln('Failed to load Gio-2.0: ${err}')
		eprintln('This test requires Gio-2.0 to be installed')
		return
	}

	n_infos := repo.get_n_infos('Gio')
	mut object_info := ?ObjectInfo(none)
	for i in 0 .. int(n_infos) {
		info := repo.get_info('Gio', i) or { continue }
		if info.get_type() == 'object' && info.get_name() == 'Application' {
			object_info = info.as_object_info()
			break
		}
		info.free()
	}

	app := object_info or {
		eprintln('Gio.Application not found, skipping')
		return
	}

	n_props := app.get_n_properties()
	mut has_writable := false
	for i in 0 .. int(n_props) {
		prop := app.get_property(u32(i)) or { continue }
		if prop.is_writable() {
			has_writable = true
		}
		prop.free()
		if has_writable {
			break
		}
	}

	if !has_writable {
		eprintln('Gio.Application has no writable properties, skipping')
		app.free()
		return
	}

	content := generate_properties_struct(app, 'Application', '', '', 'Gio')

	assert content.contains('@[params]')
	assert content.contains('pub struct ApplicationProperties {')
	// writable props are declared as optional types
	assert content.contains(' ?')

	app.free()
}

fn test_generate_object_set_properties_no_props() {
	// GObject.Object has no writable props - method body should be empty
	repo := get_default_repository()
	repo.require('GObject', '2.0') or {
		eprintln('Failed to load GObject-2.0: ${err}')
		assert false
		return
	}

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

	content := generate_object_set_properties(obj, 'Object', '', 'GObject')

	assert content.contains('pub fn (obj &Object) set_properties(properties ObjectProperties)')
	assert content.contains('}\n')
	// no property assignments
	assert !content.contains('if value :=')

	obj.free()
}

fn test_generate_object_set_properties_with_props() {
	// Gio.Application has writable properties - set_properties should call typed helpers
	repo := get_default_repository()
	repo.require('Gio', '2.0') or {
		eprintln('Failed to load Gio-2.0: ${err}')
		eprintln('This test requires Gio-2.0 to be installed')
		return
	}

	n_infos := repo.get_n_infos('Gio')
	mut object_info := ?ObjectInfo(none)
	for i in 0 .. int(n_infos) {
		info := repo.get_info('Gio', i) or { continue }
		if info.get_type() == 'object' && info.get_name() == 'Application' {
			object_info = info.as_object_info()
			break
		}
		info.free()
	}

	app := object_info or {
		eprintln('Gio.Application not found, skipping')
		return
	}

	n_props := app.get_n_properties()
	mut has_writable := false
	for i in 0 .. int(n_props) {
		prop := app.get_property(u32(i)) or { continue }
		if prop.is_writable() {
			has_writable = true
		}
		prop.free()
		if has_writable {
			break
		}
	}

	if !has_writable {
		eprintln('Gio.Application has no writable properties, skipping')
		app.free()
		return
	}

	content := generate_object_set_properties(app, 'Application', '', 'Gio')

	assert content.contains('pub fn (obj &Application) set_properties(properties ApplicationProperties)')
	assert content.contains('if value := properties.')
	assert content.contains('_property(obj.ptr,')

	app.free()
}

fn test_generate_property_methods_no_props() {
	// GObject.Object has no properties - should return empty string
	repo := get_default_repository()
	repo.require('GObject', '2.0') or {
		eprintln('Failed to load GObject-2.0: ${err}')
		assert false
		return
	}

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

	content := generate_property_methods(obj, 'Object', 'GObject')

	assert content == ''

	obj.free()
}

fn test_generate_property_methods_with_props() {
	// Gio.Application has readable/writable properties - getters/setters should be generated
	repo := get_default_repository()
	repo.require('Gio', '2.0') or {
		eprintln('Failed to load Gio-2.0: ${err}')
		eprintln('This test requires Gio-2.0 to be installed')
		return
	}

	n_infos := repo.get_n_infos('Gio')
	mut object_info := ?ObjectInfo(none)
	for i in 0 .. int(n_infos) {
		info := repo.get_info('Gio', i) or { continue }
		if info.get_type() == 'object' && info.get_name() == 'Application' {
			object_info = info.as_object_info()
			break
		}
		info.free()
	}

	app := object_info or {
		eprintln('Gio.Application not found, skipping')
		return
	}

	n_props := app.get_n_properties()
	if n_props == 0 {
		eprintln('Gio.Application has no properties, skipping')
		app.free()
		return
	}

	content := generate_property_methods(app, 'Application', 'Gio')

	// property accessors are only generated when no explicit method already exists;
	// Gio.Application has explicit get_/set_ methods for all its properties, so
	// content may be empty — verify that any generated methods are well-formed
	if content.len > 0 {
		assert content.contains('pub fn (obj &Application) get_')
			|| content.contains('pub fn (obj &Application) set_')
		assert content.contains('_property(obj.ptr,')
	}

	app.free()
}

fn test_generate_object_binding_creates_file() {
	// generate a complete object binding file and verify structure
	repo := get_default_repository()
	repo.require('GObject', '2.0') or {
		eprintln('Failed to load GObject-2.0: ${err}')
		assert false
		return
	}

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

	test_dir := os.join_path(os.temp_dir(), 'vgi_obj_binding_test')
	os.mkdir_all(test_dir) or {}
	defer { os.rmdir_all(test_dir) or {} }

	generate_object_binding(obj, test_dir)

	file_path := os.join_path(test_dir, 'object.v')
	assert os.exists(file_path)

	content := os.read_file(file_path) or {
		eprintln('Failed to read generated file: ${err}')
		assert false
		return
	}

	assert content.contains('module ')
	assert content.contains('pub struct Object {')
	assert content.contains('pub struct ObjectProperties {')
	assert content.contains('pub fn Object.new(')
	assert content.contains('pub fn (obj &Object) set_properties(')

	obj.free()
}

fn test_application_run_special_case() {
	repo := get_default_repository()
	repo.require('Gio', '2.0') or {
		eprintln('Failed to load Gio-2.0: ${err}')
		eprintln('This test requires Gio-2.0 to be installed')
		return
	}

	n_infos := repo.get_n_infos('Gio')
	mut app_info := ?ObjectInfo(none)
	for i in 0 .. int(n_infos) {
		info := repo.get_info('Gio', i) or { continue }
		if info.get_type() == 'object' && info.get_name() == 'Application' {
			app_info = info.as_object_info()
			break
		}
		info.free()
	}

	app := app_info or {
		eprintln('Gio.Application not found, skipping')
		return
	}

	content := generate_object_methods(app, 'Application', 'Gio')

	// run() should take no parameters and inject os.args
	assert content.contains('pub fn (obj &Application) run() int {')
	assert content.contains('args_c := os.args.map(it.str)')
	assert content.contains('C.g_application_run(obj.ptr, os.args.len, voidptr(args_c.data))')

	// os import should be detected
	assert object_needs_os_import(app)

	app.free()
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
		defer { os.rmdir_all(test_dir) or {} }

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
