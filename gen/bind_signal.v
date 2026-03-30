module gen

// generate signal bindings (connect methods) for a struct.
// each signal produces a connect_<signal>(cb fn()) or connect_<signal>(cb fn() bool) method.
// the shared trampoline infrastructure in v_util.v routes GLib callbacks into V closures.
fn generate_signal_bindings(signals []SignalInfo, struct_name string, namespace string) string {
	mut content := ''
	for sig in signals {
		content += generate_signal_connect(sig, struct_name, namespace)
	}
	return content
}

fn generate_signal_connect(sig SignalInfo, struct_name string, namespace string) string {
	sig_name := sig.get_name()
	if sig_name.starts_with('_') {
		return ''
	}

	v_method_name := 'connect_' + sig_name.replace('-', '_')
	n_extra := int(sig.get_n_args())

	// determine return type; only void and bool are supported — others are skipped
	return_type_info := sig.get_return_type()
	return_vtype := return_type_info.to_v_type(namespace)
	return_type_info.free()
	skip_return := sig.skip_return() || return_vtype.name == 'void'
	is_bool_return := !skip_return && return_vtype.name == 'bool'
	if !skip_return && !is_bool_return {
		return '' // unsupported return type; skip
	}

	// pick the trampoline and closure box from the static set in v_util.v
	tag := if is_bool_return { 'b' } else { 'v' }
	trampoline := 'v_trampoline_${tag}${n_extra}'
	box_type := if is_bool_return { 'VSignalBoolClosure' } else { 'VSignalVoidClosure' }
	cb_type := if is_bool_return { 'fn() bool' } else { 'fn()' }

	mut content := 'pub fn (obj &${struct_name}) ${v_method_name}(cb ${cb_type}) u64 {\n'
	content += '\tbox := &${box_type}{ call: cb }\n'
	content += "\treturn C.g_signal_connect_data(obj.ptr, c'${sig_name}', voidptr(${trampoline}), voidptr(box), voidptr(v_closure_notify), 0)\n"
	content += '}\n\n'
	return content
}
