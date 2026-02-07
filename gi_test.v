module vgi

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
	return_v_type := return_type.to_v_type()
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
		arg_v_type := arg.get_v_type()
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
