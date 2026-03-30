module main

import edam.vgi.gtk_4_0 as gtk

@[heap]
struct MyApp {
	gtk.Application
mut:
	it_worked bool
}

fn MyApp.new() &MyApp {
	a := MyApp{
		Application: gtk.Application.new(version: '1.2.3')
	}
	a.connect_activate(a.on_activate)
	return &a
}

fn (mut a MyApp) on_activate() {
	println('activated!')
	a.it_worked = true
	a.quit()
}

fn main() {
	app := MyApp.new()
	app.run()
	if !app.it_worked {
		panic("it didn't work!")
	}
}
