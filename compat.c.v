module vgi

#pkgconfig --libs --cflags girepository-2.0

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
