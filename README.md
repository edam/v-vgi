# vgi

This V modue provides GObject introspection bindings for V.  This provides
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

## Quick Example

How to use Gtk 4.x on a Mac...

``` Shell
brew instll gtk4
v install edam.vgi
~/.vmodules/edam/vgi/gi.vsh Gtk 4.0
```

Then, in V...

``` V
import edam.vgi.gtk_4_0 as gtk

app := gtk.Application.new()
app.run()
```

# Installing

## GObject introspection

Vgi uses GObject introspection to work out bindings.  So you need
libgirepository instlled.

### Mac/OSX

`gobject-introspection` is a dependency of `gtk4` in brew.

``` Shell
brew install gtk4
```

## Then install vgi module

``` Shell
v install edam.vgi
```

Finally, run the `gi.vsh` script to generate bindings for V.

## Generate bindings

### Max/OSX

On my Mac, I had to help V find the pkgconfig file for `libffi`, which is a
dependency of `girepository-2.0`

``` Shell
export PKG_CONFIG_PATH="/usr/local/Homebrew/Library/Homebrew/os/mac/pkgconfig/15"
```

### Then

``` Shell
~/.vmodules/edam/vgi/gi.vsh
```

# Documentation

## Method

Although GObject Introspection (gi) can be run dynamically (such as PyGi), this
cannot be done for V, as we must run the code to generate before compiling the
programme that uses them.  `gi.vsh` does exactly this.

Generated bindings are placed in subdirectories in `vgi`, named after the
library and version (e.g., `Gtk-4.0` becomes `gtk_4_0`) for compatibility and so
that bindings for different versions of the same library can coexist.  It is
suggested that you import them with an alias:

``` V
import edam.vgi.gtk_4_0 as gtk
```

## Bindings

### Objects

Objects map to V stuct types.  Use Object.new() to create.

As well as defining `set_` and `get_` functions for properties, object
properties can also be specified via a `[params]` struct in `new()`:

``` V
obj1 := Object.new() // no properties specifiec
obj1.set_some_property("foo")
obj2 := Object.new(some_property="foo") // also works
```
