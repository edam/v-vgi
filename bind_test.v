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
