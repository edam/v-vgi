module main

import edam.vgi.gio_2_0 as gio

// compile-only checks: verify module-level functions exist with correct signatures

fn check_dbus_generate_guid() string {
	return gio.dbus_generate_guid()
}

fn check_dbus_is_guid(str string) bool {
	return gio.dbus_is_guid(str)
}

fn check_dbus_is_name(str string) bool {
	return gio.dbus_is_name(str)
}

// g_content_type_guess has an out param (result_uncertain bool):
// should generate (string, bool) return
fn check_content_type_guess(filename string) (string, bool) {
	return gio.content_type_guess(filename, voidptr(0), 0)
}

fn main() {
	_ := check_dbus_generate_guid
	_ := check_dbus_is_guid
	_ := check_dbus_is_name
	_ := check_content_type_guess
}
