# vgi

This V module provides GObject introspection bindings for V.  This provides
bindings for any GObject-based library, which includes (amongst others):
* Gtk
* Gdk
* GLib
* Pango
* Cairo

As of Gtk 4, GObject has a dynamic introspection mechanism (libgirespository),
where descriptions of the APIs (typelibs) are available at runtime via the
library to dynamically setup bindings.

For V, this module enables you to generate (and regenerate, to refresh) static
bindings, ready to be imported, based on this GObject introspection mechanism.

## Quick Start

How to use Gtk 4.x on a Mac...

``` Shell
brew install gtk4
v install edam.vgi
~/.vmodules/edam/vgi/gi.vsh Gtk 4.0
```

Then, in V...

``` V
import edam.vgi.gtk_4_0 as gtk

win := gtk.Window.new()
```

Or run the example...

``` Shell
v -d dynamic_boehm run example
```

Note: compile/run with `-d dynamic_boehm` or V's GC crashes!

# Installing

1. Install vgi
2. Install libgirepository
3. Generate bindings
4. Use library (e.g., GTK)

## 1. Install vgi

``` Shel
v install edam.vgi
```

## 2. Ensure you have libgirepository installed

Vgi uses the GObject introspection repository library, like python's PyGi.  You
need to ensure that `libgirepository` is correctly installed.

### Mac/OSX

`gobject-introspection` is a dependency of `gtk4` in brew.

``` Shell
brew install gtk4
```

## 3. Generate bindings for your favourite GObject-based libraries

Run the `gi.vsh` script to generate bindings for V.

For example:

``` Shell
~/.vmodules/edam/vgi/gi.vsh Gtk 4.0
```

### Mac/OSX

Help V find the pkgconfig file for `libffi`, which is a dependency of
`girepository-2.0`

``` Shell
export PKG_CONFIG_PATH="/usr/local/Homebrew/Library/Homebrew/os/mac/pkgconfig/15"
```

# Documentation

## Generated Bindings

Although GObject Introspection (gi) can be run dynamically (such as PyGi), this
cannot be done for V, as we must run the code to generate bindings before
compiling the programme that uses them.  `gi.vsh` does this.

Generated bindings are placed in subdirectories in `vgi`, named after the
library and version (e.g., `Gtk-4.0` becomes `gtk_4_0`) for compatibility and so
that bindings for different versions of the same library can coexist.  It is
suggested that you import them with an alias:

``` V
import edam.vgi.gtk_4_0 as gtk
```

## Library Bindings

### Objects

Objects map to V struct types.  Use Object.new() to create.

As well as defining `set_` and `get_` functions for properties, object
properties can also be specified via a named properties struct in `new()`:

``` V
obj1 := Object.new() // no properties specified
obj1.set_some_property('foo')
obj2 := Object.new(some_property: 'foo') // also works
```

### Signals

Connect signals with dedicated methods.

``` V
my_app.connect_activate(my_app.on_activate)

fn (a MyApp) on_activate() {
	println("activated!")
}
```
