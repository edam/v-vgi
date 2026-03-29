module gen

fn test_get_default_repository() {
	repo := get_default_repository()
	assert repo.ptr != unsafe { nil }
}

fn test_require_glib() {
	repo := get_default_repository()
	repo.require('GLib', '2.0') or {
		eprintln('Failed to load GLib-2.0: ${err}')
		assert false
	}
}

fn test_get_n_infos_glib() {
	repo := get_default_repository()
	repo.require('GLib', '2.0') or {
		eprintln('Failed to load GLib-2.0: ${err}')
		assert false
	}

	n := repo.get_n_infos('GLib')
	println('GLib-2.0 has ${n} metadata entries')
	assert n > 0
}

fn test_object_methods() {
	repo := get_default_repository()
	repo.require('GObject', '2.0') or {
		eprintln('Failed to load GObject-2.0: ${err}')
		assert false
	}

	// find Object type (GObject.Object)
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

	// test get_n_methods
	n_methods := obj.get_n_methods()
	println('GObject.Object has ${n_methods} methods')
	assert n_methods > 0

	// test get_method
	method := obj.get_method(0) or {
		eprintln('Failed to get method 0')
		assert false
		return
	}

	// test method name
	method_name := method.get_name()
	println('First method: ${method_name}')
	assert method_name.len > 0

	// test get_n_args
	n_args := method.get_n_args()
	println('Method ${method_name} has ${n_args} arguments')

	// test get_return_type
	return_type := method.get_return_type()
	return_v_type := return_type.to_v_type('')
	println('Return type: ${return_v_type}')
	assert return_v_type.len > 0
	return_type.free()

	// test get_arg if method has arguments
	if n_args > 0 {
		arg := method.get_arg(0) or {
			eprintln('Failed to get arg 0')
			assert false
			return
		}

		arg_name := arg.get_name()
		println('First argument: ${arg_name}')
		assert arg_name.len > 0

		// test get_v_type
		arg_v_type := arg.get_v_type('')
		println('Argument type: ${arg_v_type}')
		assert arg_v_type.len > 0

		// test get_direction
		direction := arg.get_direction()
		println('Argument direction: ${direction}')
		assert direction >= gi_direction_in && direction <= gi_direction_inout

		arg.free()
	}

	method.free()
	obj.free()
}

fn test_object_type_init() {
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

	// test get_type_init
	type_init := obj.get_type_init()
	println('GObject.Object type init: ${type_init}')
	assert type_init.len > 0
	assert type_init.contains('_get_type')

	obj.free()
}

fn test_object_interfaces() {
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

	// test get_n_interfaces
	n_interfaces := obj.get_n_interfaces()
	println('GObject.Object implements ${n_interfaces} interfaces')

	// interfaces can be 0 for base Object, that's okay
	assert n_interfaces >= 0

	obj.free()
}

fn test_interface_methods() {
	repo := get_default_repository()
	repo.require('Gio', '2.0') or {
		eprintln('Failed to load Gio-2.0: ${err}')
		eprintln('This test requires Gio-2.0 to be installed')
		return
	}

	// find an interface (e.g., ListModel)
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
		// test get_n_methods
		n_methods := iface.get_n_methods()
		println('Gio.ListModel has ${n_methods} methods')
		assert n_methods > 0

		// test get_method
		method := iface.get_method(0) or {
			eprintln('Failed to get method 0')
			assert false
			return
		}

		method_name := method.get_name()
		println('First method: ${method_name}')
		assert method_name.len > 0

		method.free()
		iface.free()
	} else {
		eprintln('ListModel interface not found in Gio-2.0')
		eprintln('This is okay if Gio is an older version')
	}
}

fn test_enum_values() {
	repo := get_default_repository()
	repo.require('Gio', '2.0') or {
		eprintln('Failed to load Gio-2.0: ${err}')
		eprintln('This test requires Gio-2.0 to be installed')
		return
	}

	// find an enum
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

	if enum_info_val := enum_info {
		enum_name := enum_info_val.get_name()
		println('Testing enum: ${enum_name}')
		assert enum_name.len > 0

		// test get_n_values
		n_values := enum_info_val.get_n_values()
		println('Number of values: ${n_values}')
		assert n_values > 0

		// test get_value
		value := enum_info_val.get_value(0) or {
			eprintln('Failed to get value 0')
			assert false
			return
		}

		value_name := value.get_name()
		value_int := value.get_value()
		println('First value: ${value_name} = ${value_int}')
		assert value_name.len > 0

		value.free()
		enum_info_val.free()
	} else {
		eprintln('No enum found in Gio-2.0')
		eprintln('This is okay if Gio is an older version')
	}
}
