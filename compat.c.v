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

// Registered type info functions
fn C.gi_registered_type_info_get_type_init_function_name(info &C.GIRegisteredTypeInfo) &char

// Property info functions
fn C.gi_property_info_get_flags(info &C.GIPropertyInfo) int

// Type info functions
fn C.gi_property_info_get_type_info(info &C.GIPropertyInfo) &C.GITypeInfo
fn C.gi_type_info_get_tag(info &C.GITypeInfo) int

// Function/callable info functions
fn C.gi_callable_info_get_n_args(info &C.GICallableInfo) u32
fn C.gi_callable_info_get_arg(info &C.GICallableInfo, n u32) &C.GIArgInfo
fn C.gi_callable_info_get_return_type(info &C.GICallableInfo) &C.GITypeInfo
fn C.gi_callable_info_may_return_null(info &C.GICallableInfo) bool
fn C.gi_callable_info_skip_return(info &C.GICallableInfo) bool
fn C.gi_function_info_get_symbol(info &C.GIFunctionInfo) &char
fn C.gi_function_info_invoke(info &C.GIFunctionInfo, in_args &C.GIArgument, n_in_args int, out_args &C.GIArgument, n_out_args int, return_value &C.GIArgument, error &&C.GError) bool

// Arg info functions
fn C.gi_arg_info_get_direction(info &C.GIArgInfo) int
fn C.gi_arg_info_get_type_info(info &C.GIArgInfo) &C.GITypeInfo
fn C.gi_arg_info_may_be_null(info &C.GIArgInfo) bool

// Error handling
fn C.g_error_free(error &C.GError)

// GObject property access
fn C.g_object_new(object_type u64, first_property_name &char) &C.GObject
fn C.g_object_get_property(object &C.GObject, property_name &char, value &C.GValue)
fn C.g_object_set_property(object &C.GObject, property_name &char, value &C.GValue)

// GValue functions
fn C.g_value_init(value &C.GValue, gtype u64) &C.GValue
fn C.g_value_unset(value &C.GValue)
fn C.g_value_get_boolean(value &C.GValue) bool
fn C.g_value_get_int(value &C.GValue) int
fn C.g_value_get_uint(value &C.GValue) u32
fn C.g_value_get_int64(value &C.GValue) i64
fn C.g_value_get_uint64(value &C.GValue) u64
fn C.g_value_get_float(value &C.GValue) f32
fn C.g_value_get_double(value &C.GValue) f64
fn C.g_value_get_string(value &C.GValue) &char
fn C.g_value_get_pointer(value &C.GValue) voidptr
fn C.g_value_set_boolean(value &C.GValue, v_boolean bool)
fn C.g_value_set_int(value &C.GValue, v_int int)
fn C.g_value_set_uint(value &C.GValue, v_uint u32)
fn C.g_value_set_int64(value &C.GValue, v_int64 i64)
fn C.g_value_set_uint64(value &C.GValue, v_uint64 u64)
fn C.g_value_set_float(value &C.GValue, v_float f32)
fn C.g_value_set_double(value &C.GValue, v_double f64)
fn C.g_value_set_string(value &C.GValue, v_string &char)
fn C.g_value_set_pointer(value &C.GValue, v_pointer voidptr)

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
struct C.GIRegisteredTypeInfo {}

@[typedef]
struct C.GIPropertyInfo {}

@[typedef]
struct C.GIFunctionInfo {}

@[typedef]
struct C.GITypeInfo {}

@[typedef]
struct C.GICallableInfo {}

@[typedef]
struct C.GIArgInfo {}

@[typedef]
struct C.GError {
	message &char
}

@[typedef]
struct C.GObject {}

@[typedef]
struct C.GValue {
	g_type u64
	data   [2]u64
}

// GIArgument union for function invocation
@[typedef]
union C.GIArgument {
	v_boolean  bool
	v_int8     i8
	v_uint8    u8
	v_int16    i16
	v_uint16   u16
	v_int32    int
	v_uint32   u32
	v_int64    i64
	v_uint64   u64
	v_float    f32
	v_double   f64
	v_pointer  voidptr
	v_string   &char
}

// Property flags
const gi_property_readable = 1 << 0
const gi_property_writable = 1 << 1

// Argument direction
const gi_direction_in = 0
const gi_direction_out = 1
const gi_direction_inout = 2

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

// GType constants (fundamental types)
const g_type_invalid = u64(0 << 2)
const g_type_none = u64(1 << 2)
const g_type_interface = u64(2 << 2)
const g_type_char = u64(3 << 2)
const g_type_uchar = u64(4 << 2)
const g_type_boolean = u64(5 << 2)
const g_type_int = u64(6 << 2)
const g_type_uint = u64(7 << 2)
const g_type_long = u64(8 << 2)
const g_type_ulong = u64(9 << 2)
const g_type_int64 = u64(10 << 2)
const g_type_uint64 = u64(11 << 2)
const g_type_enum = u64(12 << 2)
const g_type_flags = u64(13 << 2)
const g_type_float = u64(14 << 2)
const g_type_double = u64(15 << 2)
const g_type_string = u64(16 << 2)
const g_type_pointer = u64(17 << 2)
const g_type_boxed = u64(18 << 2)
const g_type_param = u64(19 << 2)
const g_type_object = u64(20 << 2)
const g_type_variant = u64(21 << 2)
