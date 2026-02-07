module vgi

#pkgconfig --libs --cflags girepository-2.0

#include <girepository/girepository.h>

// Core GIRepository functions (girepository-2.0 API)
fn C.gi_repository_dup_default() &C.GIRepository
fn C.gi_repository_require(repository &C.GIRepository, namespace &char, version &char, flags int, error &&C.GError) &C.GITypelib
fn C.gi_repository_get_n_infos(repository &C.GIRepository, namespace &char) u32
fn C.gi_repository_get_info(repository &C.GIRepository, namespace &char, index int) &C.GIBaseInfo
fn C.gi_repository_get_typelib_path(repository &C.GIRepository, namespace &char) &char
fn C.gi_repository_get_version(repository &C.GIRepository, namespace &char) &char

// Typelib functions
fn C.gi_typelib_get_namespace(typelib &C.GITypelib) &char

// Info functions
fn C.gi_base_info_get_name(info &C.GIBaseInfo) &char
fn C.gi_base_info_unref(info voidptr)

// GObject type system functions for determining info type
fn C.G_OBJECT_TYPE_NAME(instance voidptr) &char

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
