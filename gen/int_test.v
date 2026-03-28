module gen

import os

fn test_generated_bindings_integration() {
	// integration test: generate bindings, then compile each file in int_tests/ in sorted order
	// note: library names and versions are hard-coded but this is acceptable

	libraries := ['Gtk-4.0', 'Gio-2.0', 'GObject-2.0', 'Gdk-4.0']

	println('Generating bindings for integration test...')
	for lib in libraries {
		println('  Generating ${lib}...')
		parts := lib.split('-')
		generate_bindings(parts[0], parts[1])
	}

	// find test files in int_tests/ relative to this file
	int_tests_dir := os.join_path(os.dir(@FILE), 'int_tests')
	mut test_files := os.glob('${int_tests_dir}/*.v') or {
		eprintln('Failed to list int_tests directory: ${err}')
		assert false
		return
	}
	test_files.sort()

	assert test_files.len > 0, 'No test files found in ${int_tests_dir}'

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

	mut passed := 0
	for test_file in test_files {
		name := os.base(test_file)
		println('  Compiling ${name}...')

		test_bin := os.join_path(test_dir, name.replace('.v', ''))
		result := os.execute('v -o ${test_bin} ${test_file}')

		if result.exit_code != 0 {
			eprintln('Compilation failed for ${name}:')
			eprintln(result.output)
			assert false, '${name} failed to compile'
			return
		}
		passed++
	}

	println('Integration tests passed (${passed}/${test_files.len}).')
}
