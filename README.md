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

``` Shell
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

Use the static `.new()` functions, generated for each object, to instantiate
them.  They allow you to specify optional object properties (see Object Params
Structs below).

``` V
pub fn Window.new(props WindowParams) &Window{
    ...
}
```

### Properties

Methods to set/get properties are defined for each object and properties can be
optionally provided on creation (via `new()`).

``` V
win := Window.new() // no properties specified
win.set_child(some_child) // set property after creation
// or
win := Window.new(child: some_child) //  set property during creation
```

### Implementation Details

#### Object Params Structs

Each object type has an associated *params struct* (marked with `@[params]`)
which is used to pass zero or more object properties to the object constructors
to initialise them. Each params struct embeds the params struct for the object's
parent, so parent's properties are included.  E.g., `gtk.Window` has an
associated `gtk.WindowParams` struct, which embeds `gtk.WidgetParams`.

``` V
@[params]
struct WindowParams {
    WidgetParams // inherit Widget's properties
    application ?IApplication
    child ?IWidget
    ...
}
```

#### Object Interfaces

Each object type also has an associated *object interface* (not to be confused
with interfaces provided by the GObject-based library).  Object interfaces are
native V interfaces named `I*` which allow the user to use their own types,
derived from library objects, in their place (since they derive from objects
which conform to the object's interface).

For example, `gtk.Application` has an accompanying object interface,
`gtk.IApplication`.  As shown above, `gtk.WindowParams` has an `application`
property of type `gtk.IApplication`, which allows you provide a
`gtk.Application` during construction. However, you can also derive your own
`MyApp` from `gtk.Application` and use that.

``` V
struct MyApp {
    gtk.Application // MyApp derives from gtk.Application
}
app := MyApp{Application: gtk.Application.new()} // app is an IApplication
win := gtk.Window.new(application: app) // and so can also be used here
```

Note: there is a significant impact on compile time due to the addition of this
mechanism.  However, the hope is that future V improvements will address this.

## Interfaces

GObject-based interfaces map to V interfaces.

``` V
pub interface Buildable {
    set_id(id string)
    // ...
}
```

Assuming the GObject-library's interfaces are correctly defind, regular objects
which conform to them are usable where the interfaces are accepted.

### Inspection and Casting

The actual type of a returned interface can be determined with the `.is()`
method of the library's concrete objects.

``` V
buildable := get_some_buildable() // an interface
is_button := gtk.Button.is(buildable) // check type
```

The object can only be obtained from a returned interface via smartcasting.

``` V
iWf button := gtk.Button.from(iface) {
    // can use button
} else {
	// not a Button!
}
```

### Implementation Details

#### Interface Objects

Not to be confused with the objects which the library exposes, the bindings also
define a struct for each interface which the GObject-based library provides.
These shim structs are named `S*`, provide methods which conform to the returned
interface, and wrap a pointer to the underlying object.  Functions and methods
which return interfaces actually return these structs, which allows them to have
no knowledge of the actual type being returned.  This allows the user to create
their own conformant objects which can also be used wherever the interfaces are
accepted.

## Signals

Signals can be conected to closures.

``` V
button.connect_clicked(fn () {
	println("clicked!")
})
```

Signals can also be connected to methods on objects.

``` V
struct MyApp {
    gtk.Application
}

fn (a MyApp) on_activate() {
	println("activated!")
}

my_app := MyApp.new()
my_app.connect_activate(my_app.on_activate)
```
