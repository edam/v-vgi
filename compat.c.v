module vgi

// GObject Introspection (girepository-2.0) C library bindings
// Using manual flags because #pkgconfig can't resolve libffi dependency
#flag darwin -I/usr/local/Cellar/glib/2.86.3/include
#flag darwin -I/usr/local/Cellar/glib/2.86.3/include/glib-2.0
#flag darwin -I/usr/local/Cellar/glib/2.86.3/lib/glib-2.0/include
#flag darwin -I/usr/local/opt/gettext/include
#flag darwin -I/usr/local/Cellar/pcre2/10.47/include
#flag darwin -I/Library/Developer/CommandLineTools/SDKs/MacOSX15.sdk/usr/include/ffi
#flag darwin -L/usr/local/Cellar/glib/2.86.3/lib
#flag darwin -L/usr/local/opt/gettext/lib
#flag darwin -lgirepository-2.0 -lgobject-2.0 -lglib-2.0 -lintl

#include <girepository/girepository.h>

// Core GIRepository functions (girepository-2.0 API)
fn C.gi_repository_dup_default() &C.GIRepository
fn C.gi_repository_require(repository &C.GIRepository, namespace &char, version &char, flags int, error &&C.GError) &C.GITypelib
fn C.gi_repository_get_n_infos(repository &C.GIRepository, namespace &char) u32
fn C.gi_repository_get_info(repository &C.GIRepository, namespace &char, index int) &C.GIBaseInfo

// Info functions
fn C.gi_base_info_get_name(info &C.GIBaseInfo) &char
fn C.gi_base_info_get_type(info &C.GIBaseInfo) int
fn C.gi_base_info_unref(info voidptr)

// Error handling
fn C.g_error_free(error &C.GError)

// Opaque types
@[typedef]
struct C.GIRepository {}

@[typedef]
struct C.GITypelib {}

@[typedef]
struct C.GIBaseInfo {}

@[typedef]
struct C.GError {
	message &char
}
