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
fn C.gi_base_info_get_namespace(info &C.GIBaseInfo) &char
fn C.gi_base_info_unref(info voidptr)

// GObject type system functions for determining info type
fn C.G_OBJECT_TYPE_NAME(instance voidptr) &char

// Object info functions
fn C.gi_object_info_get_parent(info &C.GIObjectInfo) &C.GIObjectInfo
fn C.gi_object_info_get_n_properties(info &C.GIObjectInfo) u32
fn C.gi_object_info_get_property(info &C.GIObjectInfo, n u32) &C.GIPropertyInfo
fn C.gi_object_info_get_n_methods(info &C.GIObjectInfo) u32
fn C.gi_object_info_get_method(info &C.GIObjectInfo, n u32) &C.GIFunctionInfo

// Property info functions
fn C.gi_property_info_get_flags(info &C.GIPropertyInfo) int

// Type info functions
fn C.gi_property_info_get_type_info(info &C.GIPropertyInfo) &C.GITypeInfo
fn C.gi_type_info_get_tag(info &C.GITypeInfo) int

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
struct C.GIObjectInfo {}

@[typedef]
struct C.GIPropertyInfo {}

@[typedef]
struct C.GIFunctionInfo {}

@[typedef]
struct C.GITypeInfo {}

@[typedef]
struct C.GError {
	message &char
}

// Property flags
const gi_property_readable = 1 << 0
const gi_property_writable = 1 << 1
