import edam.vgi.gtk_4_0 as gtk

@[heap]
struct MyApp {
	gtk.Application
}

fn MyApp.new() &MyApp {
	return &MyApp{
		Application: gtk.Application.new(
			version: '1.2.3'
		)
	}
}

fn main() {
	app := MyApp.new()
	app.run()
}
