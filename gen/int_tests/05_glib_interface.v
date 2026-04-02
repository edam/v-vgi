module main

import edam.vgi.gio_2_0 as gio

fn main() {
	// gio.File is a GLib interface (GFile*); file_new_for_path should return &gio.File.
	f1 := gio.file_new_for_path('/tmp')
	f2 := gio.file_new_for_path('/tmp')
	f3 := gio.file_new_for_path('/tmp/foo')

	// Pass f2 and f3 (gio.File interface values) to equal() —
	// a GLib function that expects a GFile* interface as a parameter.
	assert f1.equal(f2)
	assert !f1.equal(f3)
}
