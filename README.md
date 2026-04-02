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

## Objects

GObject-based objects map to V struct types.  V's embedded structs are used to
"inherit" properties from parent types.  E.g., `gtk.Window` is defined with an
embedded `gtk.Widget`.

``` V
pub struct Window {
    Widget // inherit Widget's properties
}
```

Use `Object.new()` to instantiate objects.  The generated `new()` methods allow
you to optionally specify object properties (see Params Structs below).

``` V
pub fn Window.new(props WindowParams) &Window{
    ...
}
```

### Properties

Methods to set/get properties are defined on the object.  Properties can also be
specified when creating the object (with the `new()` function).

``` V
win := Window.new() // no properties specified
win.set_child(some_child) // set property after

win := Window.new(child: some_child) // also works
```

### Implementation Details

#### Object Params Structs

Each object type has an associated *params struct* which is used to pass zero or
more object properties to the object constructors to initialise it them.

``` V
win := gtk.Window.new(child: some_child)
```

The params structs for each object, marked with `@[params]`, list the properties
for that object and embed the params struct for the object's parent (so that the
parent's properties are also included).  E.g., `gtk.Window` has an associated
`gtk.WindowParams` struct, which embeds `gtk.WidgetParams`.

``` V
@[param]
struct WindowsParams {
    WidgetParams // inherit Widget's properties
    // non-inherited properties:
    application ?IApplication
	child ?IWidget
    ...
}
```

#### Object Interfaces

Each object type also has an associated *object interface* (not to be confused
with an interface provided by the library).  Object interfaces allow for user
types derived from library objects to be used in their place.

For example, the `gtk.Application` object struct has an accompanying object
interface, `gtk.IApplication`.  In the example above, the `gtk.WindowParams`
struct uses it as the type for the `application` property of the `Window`.  This
allows either a `gtk.Application` or any derived object to be used.  For
example, the user may wish to use `MyApp`, their own derived object.

``` V
struct MyApp {
    gtk.Application // derives from gtk.Application, so can be used as IApplication
}
```

Note: the addition of this mechanism significantly impacts compilation time.
However, the hope is hat future optimisation of V should address this.

## Interfaces

GLib-based interfaces are defined as V interfaces.

``` V

```

## Signals

Connect signals with dedicated methods.

``` V
my_app.connect_activate(my_app.on_activate)

fn (a MyApp) on_activate() {
	println("activated!")
}
```
