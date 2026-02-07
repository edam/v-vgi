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
