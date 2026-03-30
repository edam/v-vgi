module main

import edam.vgi.gtk_4_0 as gtk

@[heap]
struct App {
	gtk.Application
mut:
	win &Win = unsafe { nil }
}

fn App.new() &App {
	a := App{
		Application: gtk.Application.new()
	}
	a.connect_activate(a.on_activate)
	return &a
}

fn (mut a App) on_activate() {
	a.win = Win.new(a)
	a.win.present()
}

fn main() {
	app := App.new()
	app.run()
}
