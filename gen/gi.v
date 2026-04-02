module gen

import os

// Repository represents a GIRepository instance
pub struct Repository {
	ptr &C.GIRepository
}

// return the default GIRepository singleton
pub fn get_default_repository() Repository {
	return Repository{
		ptr: C.gi_repository_dup_default()
	}
}

// loads a namespace with the given version
pub fn (r Repository) require(namespace string, version string) ! {
	mut gerror := &C.GError(unsafe { nil })
	result := C.gi_repository_require(r.ptr, namespace.str, version.str, 0, &gerror)

	if result == unsafe { nil } {
		if gerror != unsafe { nil } {
			msg := unsafe { cstring_to_vstring(gerror.message) }
			C.g_error_free(gerror)
			return error(msg)
		}
		return error('Failed to load namespace ${namespace} version ${version}')
	}
}

// return the number of metadata entries in the namespace
pub fn (r Repository) get_n_infos(namespace string) u32 {
	return C.gi_repository_get_n_infos(r.ptr, namespace.str)
}

// return the full path to the typelib file for a namespace
pub fn (r Repository) get_typelib_path(namespace string) string {
	path := C.gi_repository_get_typelib_path(r.ptr, namespace.str)
	if path == unsafe { nil } {
		return ''
	}
	return unsafe { cstring_to_vstring(path) }
}

// return the version of a loaded namespace
pub fn (r Repository) get_version(namespace string) string {
	version := C.gi_repository_get_version(r.ptr, namespace.str)
	if version == unsafe { nil } {
		return ''
	}
	return unsafe { cstring_to_vstring(version) }
}

// return the metadata info at the given index
pub fn (r Repository) get_info(namespace string, index int) ?BaseInfo {
	info_ptr := C.gi_repository_get_info(r.ptr, namespace.str, index)
	if info_ptr == unsafe { nil } {
		return none
	}
	return BaseInfo{
		ptr: info_ptr
	}
}

// BaseInfo represents a GIBaseInfo metadata entry
pub struct BaseInfo {
	ptr &C.GIBaseInfo
}

// unreferences the info
pub fn (info &BaseInfo) free() {
	if info.ptr != unsafe { nil } {
		C.gi_base_info_unref(info.ptr)
	}
}

// return the name of the info
pub fn (info BaseInfo) get_name() string {
	name := C.gi_base_info_get_name(info.ptr)
	if name == unsafe { nil } {
		return ''
	}
	return unsafe { cstring_to_vstring(name) }
}

// return the namespace of the info
pub fn (info BaseInfo) get_namespace() string {
	namespace := C.gi_base_info_get_namespace(info.ptr)
	if namespace == unsafe { nil } {
		return ''
	}
	return unsafe { cstring_to_vstring(namespace) }
}

// return the GObject type name of the info (e.g., "GIFunctionInfo", "GIObjectInfo")
pub fn (info BaseInfo) get_type_name() string {
	type_name := C.G_OBJECT_TYPE_NAME(info.ptr)
	if type_name == unsafe { nil } {
		return ''
	}
	return unsafe { cstring_to_vstring(type_name) }
}

// return a simplified type string (e.g., "function", "object")
pub fn (info BaseInfo) get_type() string {
	type_name := info.get_type_name()
	// GIFunctionInfo -> function, GIObjectInfo -> object, etc.
	if type_name.starts_with('GI') && type_name.ends_with('Info') {
		// Extract middle part and lowercase it
		middle := type_name[2..type_name.len - 4]
		return middle.to_lower()
	}
	return type_name
}

// ObjectInfo represents a GIObjectInfo
pub struct ObjectInfo {
	BaseInfo
}

// casts BaseInfo to ObjectInfo
pub fn (info BaseInfo) as_object_info() ObjectInfo {
	return ObjectInfo{
		BaseInfo: info
	}
}

// return the parent object info, if any
pub fn (info ObjectInfo) get_parent() ?ObjectInfo {
	parent_ptr := C.gi_object_info_get_parent(&C.GIObjectInfo(info.ptr))
	if parent_ptr == unsafe { nil } {
		return none
	}
	return ObjectInfo{
		BaseInfo: BaseInfo{
			ptr: &C.GIBaseInfo(parent_ptr)
		}
	}
}

// return the number of properties
pub fn (info ObjectInfo) get_n_properties() u32 {
	return C.gi_object_info_get_n_properties(&C.GIObjectInfo(info.ptr))
}

// return property info at index
pub fn (info ObjectInfo) get_property(n u32) ?PropertyInfo {
	prop_ptr := C.gi_object_info_get_property(&C.GIObjectInfo(info.ptr), n)
	if prop_ptr == unsafe { nil } {
		return none
	}
	return PropertyInfo{
		BaseInfo: BaseInfo{
			ptr: &C.GIBaseInfo(prop_ptr)
		}
	}
}

// return the number of methods
pub fn (info ObjectInfo) get_n_methods() u32 {
	return C.gi_object_info_get_n_methods(&C.GIObjectInfo(info.ptr))
}

// return method info at index
pub fn (info ObjectInfo) get_method(n u32) ?FunctionInfo {
	method_ptr := C.gi_object_info_get_method(&C.GIObjectInfo(info.ptr), n)
	if method_ptr == unsafe { nil } {
		return none
	}
	return FunctionInfo{
		BaseInfo: BaseInfo{
			ptr: &C.GIBaseInfo(method_ptr)
		}
	}
}

// collect all methods; caller is responsible for freeing each element
pub fn (info ObjectInfo) collect_methods() []FunctionInfo {
	mut methods := []FunctionInfo{}
	n := info.get_n_methods()
	for i in 0 .. int(n) {
		method := info.get_method(u32(i)) or { continue }
		methods << method
	}
	return methods
}

// return the number of interfaces implemented
pub fn (info ObjectInfo) get_n_interfaces() u32 {
	return C.gi_object_info_get_n_interfaces(&C.GIObjectInfo(info.ptr))
}

// return interface info at index
pub fn (info ObjectInfo) get_interface(n u32) ?InterfaceInfo {
	iface_ptr := C.gi_object_info_get_interface(&C.GIObjectInfo(info.ptr), n)
	if iface_ptr == unsafe { nil } {
		return none
	}
	return InterfaceInfo{
		BaseInfo: BaseInfo{
			ptr: &C.GIBaseInfo(iface_ptr)
		}
	}
}

// return the number of signals
pub fn (info ObjectInfo) get_n_signals() u32 {
	return C.gi_object_info_get_n_signals(&C.GIObjectInfo(info.ptr))
}

// return signal info at index
pub fn (info ObjectInfo) get_signal(n u32) ?SignalInfo {
	sig_ptr := C.gi_object_info_get_signal(&C.GIObjectInfo(info.ptr), n)
	if sig_ptr == unsafe { nil } {
		return none
	}
	return SignalInfo{
		BaseInfo: BaseInfo{
			ptr: &C.GIBaseInfo(sig_ptr)
		}
	}
}

// collect all signals; caller is responsible for freeing each element
pub fn (info ObjectInfo) collect_signals() []SignalInfo {
	mut signals := []SignalInfo{}
	n := info.get_n_signals()
	for i in 0 .. int(n) {
		sig := info.get_signal(u32(i)) or { continue }
		signals << sig
	}
	return signals
}

// return the type initialization function name
pub fn (info ObjectInfo) get_type_init() string {
	type_init := C.gi_registered_type_info_get_type_init_function_name(&C.GIRegisteredTypeInfo(info.ptr))
	if type_init == unsafe { nil } {
		return ''
	}
	return unsafe { cstring_to_vstring(type_init) }
}

// PropertyInfo represents a GIPropertyInfo
pub struct PropertyInfo {
	BaseInfo
}

// return true if the property is readable
pub fn (info PropertyInfo) is_readable() bool {
	flags := C.gi_property_info_get_flags(&C.GIPropertyInfo(info.ptr))
	return (flags & gi_property_readable) != 0
}

// return true if the property is writable
pub fn (info PropertyInfo) is_writable() bool {
	flags := C.gi_property_info_get_flags(&C.GIPropertyInfo(info.ptr))
	return (flags & gi_property_writable) != 0
}

// return true if the property is construct-only (can only be set during construction)
pub fn (info PropertyInfo) is_construct_only() bool {
	flags := C.gi_property_info_get_flags(&C.GIPropertyInfo(info.ptr))
	return (flags & gi_property_construct_only) != 0
}

// return the type information for the property
pub fn (info PropertyInfo) get_type_info() TypeInfo {
	type_ptr := C.gi_property_info_get_type_info(&C.GIPropertyInfo(info.ptr))
	return TypeInfo{
		BaseInfo: BaseInfo{
			ptr: &C.GIBaseInfo(type_ptr)
		}
	}
}

// return the V type for the property, using object interface types for GObject subclasses
pub fn (info PropertyInfo) get_prop_type(namespace string) VType {
	type_info := info.get_type_info()
	defer { type_info.free() }
	return type_info.to_prop_type(namespace)
}

// return the GType constant name
pub fn (info PropertyInfo) get_gtype_constant() string {
	type_info := info.get_type_info()
	defer { type_info.free() }
	return type_info.to_gtype_constant()
}

// return the g_value_get_* function name
pub fn (info PropertyInfo) get_gvalue_getter() string {
	type_info := info.get_type_info()
	defer { type_info.free() }
	return type_info.to_gvalue_getter()
}

// return the g_value_set_* function name
pub fn (info PropertyInfo) get_gvalue_setter() string {
	type_info := info.get_type_info()
	defer { type_info.free() }
	return type_info.to_gvalue_setter()
}

// return true if property needs cstring conversion
pub fn (info PropertyInfo) needs_string_conversion() bool {
	type_info := info.get_type_info()
	defer { type_info.free() }
	return type_info.needs_string_conversion()
}

// return the helper function name prefix
pub fn (info PropertyInfo) get_property_helper_name() string {
	type_info := info.get_type_info()
	defer { type_info.free() }
	return type_info.to_property_helper_name()
}

// FunctionInfo represents a GIFunctionInfo
pub struct FunctionInfo {
	BaseInfo
}

// return the number of arguments
pub fn (info FunctionInfo) get_n_args() u32 {
	return C.gi_callable_info_get_n_args(&C.GICallableInfo(info.ptr))
}

// return argument info at index
pub fn (info FunctionInfo) get_arg(n u32) ?ArgInfo {
	arg_ptr := C.gi_callable_info_get_arg(&C.GICallableInfo(info.ptr), n)
	if arg_ptr == unsafe { nil } {
		return none
	}
	return ArgInfo{
		BaseInfo: BaseInfo{
			ptr: &C.GIBaseInfo(arg_ptr)
		}
	}
}

// return the return type info
pub fn (info FunctionInfo) get_return_type() TypeInfo {
	type_ptr := C.gi_callable_info_get_return_type(&C.GICallableInfo(info.ptr))
	return TypeInfo{
		BaseInfo: BaseInfo{
			ptr: &C.GIBaseInfo(type_ptr)
		}
	}
}

// return true if function can return null
pub fn (info FunctionInfo) may_return_null() bool {
	return C.gi_callable_info_may_return_null(&C.GICallableInfo(info.ptr))
}

// return true if return value should be skipped
pub fn (info FunctionInfo) skip_return() bool {
	return C.gi_callable_info_skip_return(&C.GICallableInfo(info.ptr))
}

// return true if the function can throw a GError
pub fn (info FunctionInfo) can_throw_gerror() bool {
	return C.gi_callable_info_can_throw_gerror(&C.GICallableInfo(info.ptr))
}

// GIFunctionInfoFlags
const gi_function_is_method = u32(1 << 0)
const gi_function_is_constructor = u32(1 << 1)

// return true if function is an instance method (has a self/receiver arg)
pub fn (info FunctionInfo) is_method() bool {
	flags := C.gi_function_info_get_flags(&C.GIFunctionInfo(info.ptr))
	return (flags & gi_function_is_method) != 0
}

// return true if function is a constructor (static factory, no self arg)
pub fn (info FunctionInfo) is_constructor() bool {
	flags := C.gi_function_info_get_flags(&C.GIFunctionInfo(info.ptr))
	return (flags & gi_function_is_constructor) != 0
}

// return the C symbol name for the function
pub fn (info FunctionInfo) get_symbol() string {
	symbol := C.gi_function_info_get_symbol(&C.GIFunctionInfo(info.ptr))
	if symbol == unsafe { nil } {
		return ''
	}
	return unsafe { cstring_to_vstring(symbol) }
}

// InterfaceInfo represents a GIInterfaceInfo
pub struct InterfaceInfo {
	BaseInfo
}

// casts BaseInfo to InterfaceInfo
pub fn (info BaseInfo) as_interface_info() InterfaceInfo {
	return InterfaceInfo{
		BaseInfo: info
	}
}

// return the number of methods
pub fn (info InterfaceInfo) get_n_methods() u32 {
	return C.gi_interface_info_get_n_methods(&C.GIInterfaceInfo(info.ptr))
}

// return method info at index
pub fn (info InterfaceInfo) get_method(n u32) ?FunctionInfo {
	method_ptr := C.gi_interface_info_get_method(&C.GIInterfaceInfo(info.ptr), n)
	if method_ptr == unsafe { nil } {
		return none
	}
	return FunctionInfo{
		BaseInfo: BaseInfo{
			ptr: &C.GIBaseInfo(method_ptr)
		}
	}
}

// collect all methods; caller is responsible for freeing each element
pub fn (info InterfaceInfo) collect_methods() []FunctionInfo {
	mut methods := []FunctionInfo{}
	n := info.get_n_methods()
	for i in 0 .. int(n) {
		method := info.get_method(u32(i)) or { continue }
		methods << method
	}
	return methods
}

// return the number of prerequisites (parent interfaces)
pub fn (info InterfaceInfo) get_n_prerequisites() u32 {
	return C.gi_interface_info_get_n_prerequisites(&C.GIInterfaceInfo(info.ptr))
}

// return prerequisite info at index
pub fn (info InterfaceInfo) get_prerequisite(n u32) ?BaseInfo {
	prereq_ptr := C.gi_interface_info_get_prerequisite(&C.GIInterfaceInfo(info.ptr), n)
	if prereq_ptr == unsafe { nil } {
		return none
	}
	return BaseInfo{
		ptr: prereq_ptr
	}
}

// return the number of signals
pub fn (info InterfaceInfo) get_n_signals() u32 {
	return C.gi_interface_info_get_n_signals(&C.GIInterfaceInfo(info.ptr))
}

// return signal info at index
pub fn (info InterfaceInfo) get_signal(n u32) ?SignalInfo {
	sig_ptr := C.gi_interface_info_get_signal(&C.GIInterfaceInfo(info.ptr), n)
	if sig_ptr == unsafe { nil } {
		return none
	}
	return SignalInfo{
		BaseInfo: BaseInfo{
			ptr: &C.GIBaseInfo(sig_ptr)
		}
	}
}

// collect all signals; caller is responsible for freeing each element
pub fn (info InterfaceInfo) collect_signals() []SignalInfo {
	mut signals := []SignalInfo{}
	n := info.get_n_signals()
	for i in 0 .. int(n) {
		sig := info.get_signal(u32(i)) or { continue }
		signals << sig
	}
	return signals
}

// SignalInfo represents a GISignalInfo (subtype of GICallableInfo)
pub struct SignalInfo {
	BaseInfo
}

// return the number of arguments (not including sender or user_data)
pub fn (info SignalInfo) get_n_args() u32 {
	return C.gi_callable_info_get_n_args(&C.GICallableInfo(info.ptr))
}

// return argument info at index
pub fn (info SignalInfo) get_arg(n u32) ?ArgInfo {
	arg_ptr := C.gi_callable_info_get_arg(&C.GICallableInfo(info.ptr), n)
	if arg_ptr == unsafe { nil } {
		return none
	}
	return ArgInfo{
		BaseInfo: BaseInfo{
			ptr: &C.GIBaseInfo(arg_ptr)
		}
	}
}

// return the return type info
pub fn (info SignalInfo) get_return_type() TypeInfo {
	type_ptr := C.gi_callable_info_get_return_type(&C.GICallableInfo(info.ptr))
	return TypeInfo{
		BaseInfo: BaseInfo{
			ptr: &C.GIBaseInfo(type_ptr)
		}
	}
}

// return true if return value should be skipped
pub fn (info SignalInfo) skip_return() bool {
	return C.gi_callable_info_skip_return(&C.GICallableInfo(info.ptr))
}

// EnumInfo represents a GIEnumInfo (enums and flags)
pub struct EnumInfo {
	BaseInfo
}

// creates a FunctionInfo from a BaseInfo, taking a new reference.
// the caller remains responsible for freeing the original BaseInfo.
pub fn FunctionInfo.from_info(info BaseInfo) FunctionInfo {
	C.gi_base_info_ref(info.ptr)
	return FunctionInfo{
		BaseInfo: info
	}
}

// casts BaseInfo to EnumInfo
pub fn (info BaseInfo) as_enum_info() EnumInfo {
	return EnumInfo{
		BaseInfo: info
	}
}

// return the number of values in the enum
pub fn (info EnumInfo) get_n_values() u32 {
	return C.gi_enum_info_get_n_values(&C.GIEnumInfo(info.ptr))
}

// return value info at index
pub fn (info EnumInfo) get_value(n u32) ?ValueInfo {
	value_ptr := C.gi_enum_info_get_value(&C.GIEnumInfo(info.ptr), n)
	if value_ptr == unsafe { nil } {
		return none
	}
	return ValueInfo{
		BaseInfo: BaseInfo{
			ptr: &C.GIBaseInfo(value_ptr)
		}
	}
}

// return the storage type for the enum
pub fn (info EnumInfo) get_storage_type() int {
	return C.gi_enum_info_get_storage_type(&C.GIEnumInfo(info.ptr))
}

// ValueInfo represents a GIValueInfo (enum/flags value)
pub struct ValueInfo {
	BaseInfo
}

// return the integer value
pub fn (info ValueInfo) get_value() i64 {
	return C.gi_value_info_get_value(&C.GIValueInfo(info.ptr))
}

// ArgInfo represents a GIArgInfo
pub struct ArgInfo {
	BaseInfo
}

// return the argument direction (in/out/inout)
pub fn (info ArgInfo) get_direction() int {
	return C.gi_arg_info_get_direction(&C.GIArgInfo(info.ptr))
}

// return the type information for the argument
pub fn (info ArgInfo) get_type_info() TypeInfo {
	type_ptr := C.gi_arg_info_get_type_info(&C.GIArgInfo(info.ptr))
	return TypeInfo{
		BaseInfo: BaseInfo{
			ptr: &C.GIBaseInfo(type_ptr)
		}
	}
}

// return true if argument can be null
pub fn (info ArgInfo) may_be_null() bool {
	return C.gi_arg_info_may_be_null(&C.GIArgInfo(info.ptr))
}

// return the V type for the argument
pub fn (info ArgInfo) get_v_type(namespace string) VType {
	type_info := info.get_type_info()
	defer { type_info.free() }
	return type_info.to_v_type(namespace)
}

// return true if the argument type is an enum or flags, regardless of namespace
pub fn (info ArgInfo) is_enum_or_flags() bool {
	type_info := info.get_type_info()
	defer { type_info.free() }
	iface := type_info.get_interface_info() or { return false }
	defer { iface.free() }
	t := iface.get_type()
	return t == 'enum' || t == 'flags'
}

// VTypeKind classifies how a resolved V property type should be handled at the call site.
pub enum VTypeKind {
	plain        // scalar, string, voidptr — passed directly
	enum_flags   // same-namespace enum/flags — cast to/from int
	object_iface // GObject subclass interface (IFoo / ns.IFoo) — call val.object_ptr()
	object       // GLib concrete wrapper (&Foo for same-namespace GLib interfaces) — access val.ptr
}

// VType holds a resolved V type name and its kind, plus optional cross-namespace import info.
pub struct VType {
pub:
	name         string
	kind         VTypeKind
	import_alias string // non-empty if this type requires an import (e.g. 'gdk')
	import_path  string // full import path (e.g. 'edam.vgi.gdk_4_0')
}

// for object_iface types, return the concrete struct type name (strips the leading I).
// 'IApplication' → 'Application'; 'gdk.IDisplay' → 'gdk.Display'
pub fn (t VType) concrete_name() string {
	if t.name.contains('.') {
		parts := t.name.split('.')
		return '${parts[0]}.${parts[1][1..]}'
	}
	return t.name[1..]
}

// return the equivalent C type for use in fn C.xxx() declarations
pub fn (t VType) to_c_type() string {
	return match t.name {
		'string' { '&char' }
		'bool' { 'bool' }
		'void', 'i8', 'u8', 'i16', 'u16', 'int', 'u32', 'i64', 'u64', 'f32', 'f64' { t.name }
		'i32' { 'int' }
		'voidptr' { 'voidptr' }
		else {
			if t.name.starts_with('&') { 'voidptr' } else { 'int' } // enum/flags type names
		}
	}
}

// return the C return sig for fn C.xxx() declarations
pub fn (t VType) to_c_return_sig(skip_return bool) string {
	return if skip_return || t.name == 'void' { '' } else { t.to_c_type() }
}

// return a zero/nil literal for this type, used as out-param and default initialiser.
// numeric types other than int use explicit casts to avoid V inferring int.
pub fn (t VType) default_value() string {
	return match t.name {
		'bool' { 'false' }
		'string' { "''" }
		'int' { '0' }
		'i8', 'u8', 'i16', 'u16', 'u32', 'i64', 'u64' { '${t.name}(0)' }
		'f32', 'f64' { '${t.name}(0.0)' }
		'voidptr' { 'unsafe { nil }' }
		else {
			if t.name.starts_with('&') { 'unsafe { nil }' } else { 'unsafe { ${t.name}(0) }' } // enum/flags
		}
	}
}

// return the V return signature for method bindings
pub fn (t VType) to_v_return_sig(can_error bool, may_null bool, skip_return bool) string {
	if skip_return || t.name == 'void' {
		return if can_error { '!' } else { '' }
	}
	is_nullable_type := t.name == 'string' || t.name == 'voidptr' || t.name.starts_with('&')
	// V does not support !?T — when both can_error and may_null, use !T (nil treated as error)
	if may_null && is_nullable_type && !can_error {
		return '?${t.name}'
	}
	return if can_error { '!${t.name}' } else { t.name }
}

// TypeInfo represents a GITypeInfo
pub struct TypeInfo {
	BaseInfo
}

// return the type tag
pub fn (info TypeInfo) get_tag() int {
	return C.gi_type_info_get_tag(&C.GITypeInfo(info.ptr))
}

// return true if the type is a pointer
pub fn (info TypeInfo) is_pointer() bool {
	return C.gi_type_info_is_pointer(&C.GITypeInfo(info.ptr))
}

// return the interface BaseInfo for a gi_type_tag_interface type, or none otherwise
pub fn (info TypeInfo) get_interface_info() ?BaseInfo {
	if info.get_tag() != gi_type_tag_interface {
		return none
	}
	iface_ptr := C.gi_type_info_get_interface(&C.GITypeInfo(info.ptr))
	if iface_ptr == unsafe { nil } {
		return none
	}
	return BaseInfo{
		ptr: iface_ptr
	}
}

// converts the type to a VType for use in generated code.
// namespace is the GI namespace of the module being generated (e.g. "Gio"),
// as returned by gi_base_info_get_namespace() — capitalised, not lowercased.
// used to produce unqualified names for same-namespace enum/flags types.
pub fn (info TypeInfo) to_v_type(namespace string) VType {
	type_tag := info.get_tag()
	is_pointer := info.is_pointer()
	base_name := match type_tag {
		gi_type_tag_boolean { 'bool' }
		gi_type_tag_int8 { 'i8' }
		gi_type_tag_uint8 { 'u8' }
		gi_type_tag_int16 { 'i16' }
		gi_type_tag_uint16 { 'u16' }
		gi_type_tag_int32 { 'int' }
		gi_type_tag_uint32 { 'u32' }
		gi_type_tag_int64 { 'i64' }
		gi_type_tag_uint64 { 'u64' }
		gi_type_tag_float { 'f32' }
		gi_type_tag_double { 'f64' }
		gi_type_tag_gtype { 'u64' } // size_t
		gi_type_tag_void { return if is_pointer { VType{name: 'voidptr'} } else { VType{name: 'void'} } }
		gi_type_tag_utf8, gi_type_tag_filename { return VType{name: 'string'} }
		gi_type_tag_interface {
			iface := info.get_interface_info() or { return VType{name: 'voidptr'} }
			defer { iface.free() }
			iface_type := iface.get_type()
			if iface_type == 'enum' || iface_type == 'flags' {
				iface_name := iface.get_name()
				iface_ns := iface.get_namespace()
				if iface_ns == namespace {
					return VType{name: iface_name, kind: .enum_flags}
				} else {
					// cross-namespace enum/flags: use int (C-compatible, avoids import)
					return VType{name: 'int'}
				}
			}
			return VType{name: 'voidptr'}
		}
		else { return VType{name: 'voidptr'} } // arrays, lists, hash tables, etc.
	}
	return if is_pointer { VType{name: '&${base_name}'} } else { VType{name: base_name} }
}

// return the V type for a property. GObject subclass types become object interface types
// (IFoo or ns.IFoo with import info) so user-derived structs can satisfy the interface.
// GLib interface types stay as concrete &Foo wrappers (same namespace) or voidptr (cross).
pub fn (info TypeInfo) to_prop_type(namespace string) VType {
	if info.get_tag() == gi_type_tag_interface {
		iface := info.get_interface_info() or { return VType{name: 'voidptr'} }
		defer { iface.free() }
		iface_type := iface.get_type()
		if iface_type == 'enum' || iface_type == 'flags' {
			iface_name := iface.get_name()
			iface_ns := iface.get_namespace()
			if iface_ns == namespace {
				return VType{name: iface_name, kind: .enum_flags}
			} else {
				return VType{name: 'int'}
			}
		}
		// GObject subclasses: emit object interface type (IFoo / ns.IFoo) so that
		// user-derived structs embedding the generated struct can satisfy the interface.
		if iface_type == 'object' {
			iface_name := iface.get_name()
			iface_ns := iface.get_namespace()
			if iface_ns == namespace {
				return VType{name: 'I${iface_name}', kind: .object_iface}
			} else {
				repo := get_default_repository()
				version := repo.get_version(iface_ns)
				module_path := get_binding_dir_name(iface_ns, version)
				// only emit cross-namespace interface if the binding directory exists;
				// otherwise fall through to voidptr (user must generate that namespace first)
				if !os.is_dir(get_vmod_path(module_path)) {
					return VType{name: 'voidptr'}
				}
				alias := iface_ns.to_lower()
				return VType{
					name: '${alias}.I${iface_name}'
					kind: .object_iface
					import_alias: alias
					import_path: 'edam.vgi.${module_path}'
				}
			}
		}
		// GLib interface types: concrete &Foo wrapper (same namespace) or plain voidptr (cross).
		// These are not wired into the V interface system, so we use the C wrapper struct directly.
		if iface_type == 'interface' {
			if iface.get_namespace() == namespace {
				return VType{name: '&${iface.get_name()}', kind: .object}
			}
		}
		return VType{name: 'voidptr'}
	}
	return info.to_v_type(namespace)
}

// return the GType constant name for code generation
pub fn (info TypeInfo) to_gtype_constant() string {
	tag := info.get_tag()
	return match tag {
		gi_type_tag_void { 'g_type_pointer' }
		gi_type_tag_boolean { 'g_type_boolean' }
		gi_type_tag_int8, gi_type_tag_int16, gi_type_tag_int32 { 'g_type_int' }
		gi_type_tag_uint8, gi_type_tag_uint16, gi_type_tag_uint32 { 'g_type_uint' }
		gi_type_tag_int64 { 'g_type_int64' }
		gi_type_tag_uint64, gi_type_tag_gtype { 'g_type_uint64' }
		gi_type_tag_float { 'g_type_float' }
		gi_type_tag_double { 'g_type_double' }
		gi_type_tag_utf8, gi_type_tag_filename { 'g_type_string' }
		else { 'g_type_pointer' }
	}
}

// return the g_value_get_* function name
pub fn (info TypeInfo) to_gvalue_getter() string {
	tag := info.get_tag()
	return match tag {
		gi_type_tag_boolean { 'g_value_get_boolean' }
		gi_type_tag_int8, gi_type_tag_int16, gi_type_tag_int32 { 'g_value_get_int' }
		gi_type_tag_uint8, gi_type_tag_uint16, gi_type_tag_uint32 { 'g_value_get_uint' }
		gi_type_tag_int64 { 'g_value_get_int64' }
		gi_type_tag_uint64, gi_type_tag_gtype { 'g_value_get_uint64' }
		gi_type_tag_float { 'g_value_get_float' }
		gi_type_tag_double { 'g_value_get_double' }
		gi_type_tag_utf8, gi_type_tag_filename { 'g_value_get_string' }
		else { 'g_value_get_pointer' }
	}
}

// return the g_value_set_* function name
pub fn (info TypeInfo) to_gvalue_setter() string {
	tag := info.get_tag()
	return match tag {
		gi_type_tag_boolean { 'g_value_set_boolean' }
		gi_type_tag_int8, gi_type_tag_int16, gi_type_tag_int32 { 'g_value_set_int' }
		gi_type_tag_uint8, gi_type_tag_uint16, gi_type_tag_uint32 { 'g_value_set_uint' }
		gi_type_tag_int64 { 'g_value_set_int64' }
		gi_type_tag_uint64, gi_type_tag_gtype { 'g_value_set_uint64' }
		gi_type_tag_float { 'g_value_set_float' }
		gi_type_tag_double { 'g_value_set_double' }
		gi_type_tag_utf8, gi_type_tag_filename { 'g_value_set_string' }
		else { 'g_value_set_pointer' }
	}
}

// return true if the type needs cstring conversion
pub fn (info TypeInfo) needs_string_conversion() bool {
	tag := info.get_tag()
	return tag == gi_type_tag_utf8 || tag == gi_type_tag_filename
}

// return the helper function name prefix (e.g., "bool", "int", "string")
// used to select get_X_property / set_X_property helpers in generated code
pub fn (info TypeInfo) to_property_helper_name() string {
	if info.get_tag() == gi_type_tag_interface {
		iface := info.get_interface_info() or { return 'voidptr' }
		defer { iface.free() }
		t := iface.get_type()
		if t == 'enum' || t == 'flags' { return 'int' }
		if t == 'object' || t == 'interface' { return 'object' }
		return 'voidptr' // struct, union, boxed types
	}
	tag := info.get_tag()
	return match tag {
		gi_type_tag_boolean { 'bool' }
		gi_type_tag_int8 { 'i8' }
		gi_type_tag_uint8 { 'u8' }
		gi_type_tag_int16, gi_type_tag_int32 { 'int' }
		gi_type_tag_uint16, gi_type_tag_uint32 { 'u32' }
		gi_type_tag_int64 { 'i64' }
		gi_type_tag_uint64, gi_type_tag_gtype { 'u64' }
		gi_type_tag_float { 'f32' }
		gi_type_tag_double { 'f64' }
		gi_type_tag_utf8, gi_type_tag_filename { 'string' }
		else { 'voidptr' }
	}
}
