import edam.vgi.gtk_4_0 as gtk

@[heap]
struct MyApp {
	gtk.Application
}

fn MyApp.new() &MyApp {
	a := MyApp{
		Application: gtk.Application.new(
			version: '1.2.3'
		)
	}
	//	a.connect('activate', a.on_activate)
	return &a
}

// fn (mut a MyApp) on_activate() {
// 	a.win.present()
// }

fn main() {
	app := MyApp.new()
	app.run()
}
