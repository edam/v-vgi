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
~/.vmodules/edam/vgi/gen.vsh
```

Then, in V...

``` V
import vgi.gtk
gtk.require_version("4.0")
app := gtk.Application()
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

Finally, run the `gen` script to generate bindings for V.

## Generate bindings

``` Shell
~/.vmodules/edam/vgi/gen.vsh
```
