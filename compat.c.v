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

// GITypeTag enum values
const gi_type_tag_void = 0
const gi_type_tag_boolean = 1
const gi_type_tag_int8 = 2
const gi_type_tag_uint8 = 3
const gi_type_tag_int16 = 4
const gi_type_tag_uint16 = 5
const gi_type_tag_int32 = 6
const gi_type_tag_uint32 = 7
const gi_type_tag_int64 = 8
const gi_type_tag_uint64 = 9
const gi_type_tag_float = 10
const gi_type_tag_double = 11
const gi_type_tag_gtype = 12
const gi_type_tag_utf8 = 13
const gi_type_tag_filename = 14
const gi_type_tag_array = 15
const gi_type_tag_interface = 16
const gi_type_tag_glist = 17
const gi_type_tag_gslist = 18
const gi_type_tag_ghash = 19
const gi_type_tag_error = 20
const gi_type_tag_unichar = 21
