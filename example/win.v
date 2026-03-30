module main

import edam.vgi.gtk_4_0 as gtk

@[heap]
struct Win {
	gtk.ApplicationWindow
}

fn Win.new(app &App) &Win {
	w := Win{
		ApplicationWindow: gtk.ApplicationWindow.new(
			application: app
		)
	}
	return &w
}

fn (mut w Win) on_close() {
	w.destroy()
}
