module gen

import os

const test_code = "
module main

import edam.vgi.gtk_4_0 as gtk

fn test_window_ctor() !&gtk.Window {
	return gtk.Window.new()
}

fn test_label_ctor() !&gtk.Label {
	return gtk.Label.new('Hello')
}

fn main() {
	// exercise named constructors (compile-only check; GTK not initialised)
	_ := test_window_ctor
	_ := test_label_ctor
}
"

fn test_generated_bindings_integration() {
	// integration test: generate bindings and verify they compile
	// note: library names and versions are hard-coded but this is acceptable

	libraries := ['Gtk-4.0', 'Gio-2.0', 'GObject-2.0', 'Gdk-4.0']

	println('Generating bindings for integration test...')
	for lib in libraries {
		println('  Generating ${lib}...')
		parts := lib.split('-')
		generate_bindings(parts[0], parts[1])
	}

	println('Creating test application...')

	// create temporary directory in /tmp
	test_dir := os.join_path('/tmp', 'vgi_int_test_${os.getpid()}')
	os.mkdir_all(test_dir) or {
		eprintln('Failed to create test directory: ${err}')
		assert false
		return
	}

	defer {
		os.rmdir_all(test_dir) or {}
	}

	// create test V file
	test_file := os.join_path(test_dir, 'vgi_int.v')
	os.write_file(test_file, test_code) or {
		eprintln('Failed to write test file: ${err}')
		assert false
		return
	}

	println('Compiling test application...')

	// compile only (not run) — generated bindings may require GTK display/init at runtime
	test_bin := os.join_path(test_dir, 'test_bin')
	result := os.execute('v -o ${test_bin} ${test_file}')

	if result.exit_code != 0 {
		eprintln('Compilation failed:')
		eprintln(result.output)
		assert false, 'Generated bindings failed to compile'
	}

	println('Integration test passed!')
}
