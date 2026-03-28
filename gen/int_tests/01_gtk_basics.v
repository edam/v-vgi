module main

import edam.vgi.gtk_4_0 as gtk

fn test_window_ctor() &gtk.Window {
	return gtk.Window.new()
}

fn test_label_ctor() &gtk.Label {
	return gtk.Label.new(label: 'Hello')
}

fn main() {
	// compile-only check; GTK not initialised at runtime
	_ := test_window_ctor
	_ := test_label_ctor
}
