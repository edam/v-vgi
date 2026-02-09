module gen

import os

fn test_generated_bindings_integration() {
	// integration test: generate bindings and verify they compile
	// note: library names and versions are hard-coded but this is acceptable

	libraries := ['Gtk-4.0', 'Gio-2.0', 'GObject-2.0', 'Gdk-4.0']

	println('Generating bindings for integration test...')
	for lib in libraries {
		println('  Generating ${lib}...')
		// parse library-version format
		last_hyphen := lib.last_index('-') or {
			eprintln('Failed to parse ${lib}')
			assert false
			return
		}
		library := lib[..last_hyphen]
		version := lib[last_hyphen + 1..]

		// generate bindings
		generate_bindings(library, version)
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
	test_code := "module main

import edam.vgi.gtk_4_0 as gtk

struct MyApp {
	gtk.Application
}

fn main() {
	app := MyApp{}
	// note: run() requires arguments in real usage, but we're just testing compilation
	println('MyApp created successfully')
}
"

	test_file := os.join_path(test_dir, 'vgi_int_test.v')
	os.write_file(test_file, test_code) or {
		eprintln('Failed to write test file: ${err}')
		assert false
		return
	}

	println('Compiling test application...')

	// try to compile the test file
	result := os.execute('v run ${test_file}')

	if result.exit_code != 0 {
		eprintln('Compilation failed:')
		eprintln(result.output)
		assert false, 'Generated bindings failed to compile'
	}

	println('Integration test passed!')
}
