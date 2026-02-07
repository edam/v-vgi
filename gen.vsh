#!/usr/bin/env v run

import os
import regex
import edam.ggetopt
import edam.vgi

const description = 'GObject introspection bindings (re)generator for V'
const options = [
	ggetopt.text(description),
	ggetopt.text(),
	ggetopt.text('Usage: ${ggetopt.prog()} LIBRARY VERSION'),
	ggetopt.text(),
	ggetopt.text('Options:'),
	ggetopt.opt('info', `i`).help('display information about the library'),
	ggetopt.opt_help(),
	ggetopt.opt_version(),
	ggetopt.text(),
	ggetopt.text('E.g., to generate (or regenerate) gtk 4.x series bindings:'),
	ggetopt.text('  ~/.vmodules/edam/vgi/gen.vsh gtk 4.0'),
	ggetopt.text('Then you can go "import edam.vgi.gtk" in your V apps.'),
]

@[heap]
struct Options {
mut:
	info bool
}

fn get_version() string {
	mut re := regex.regex_opt(r".*version: *'([0-9.]+)'.*") or { return '' }
	vmod := os.read_lines(vgi.get_vmod_path('v.mod')) or { return 'unknown' }
	for line in vmod {
		if re.matches_string(line) {
			return re.get_group_by_id(line, 0)
		}
	}
	return 'unknown'
}

fn (mut o Options) process_arg(arg string, val ?string) ! {
	match arg {
		'info' {
			o.info = true
		}
		'help' {
			ggetopt.print_help(options)
			exit(0)
		}
		'version' {
			version := get_version()
			println('vgi ${version}\t\t${description}')
			exit(0)
		}
		else {}
	}
}

fn main() {
	mut opts := Options{}
	args := ggetopt.getopt_long_cli(options, opts.process_arg) or { ggetopt.die_hint(err) }
	if args.len > 2 {
		ggetopt.die_hint('extra arguments on command line')
	} else if args.len < 2 {
		ggetopt.die_hint('too few arguments on command line')
	}

	library := args[0]
	version := args[1]

	if opts.info {
		show_info(library, version)
		exit(0)
	}

	// generate bindings
	vgi.generate_bindings(library, version)
}

fn show_info(library string, version string) {
	repo := vgi.get_default_repository()

	// load library
	repo.require(library, version) or {
		eprintln('Error: Failed to load library ${library}-${version}')
		eprintln('${err}')
		exit(1)
	}

	println('Library found: ${library}-${version}')

	// get typelib path
	path := repo.get_typelib_path(library)
	if path != '' {
		println('Typelib path: ${path}')
	}

	// get loaded version
	loaded_version := repo.get_version(library)
	if loaded_version != '' {
		println('Loaded version: ${loaded_version}')
	}

	// get metadata count
	n_infos := repo.get_n_infos(library)
	println('Metadata entries: ${n_infos}')

	// collect entries by type
	mut counts := map[string]int{}
	mut entries_by_type := map[string][]string{}

	for i in 0 .. int(n_infos) {
		info := repo.get_info(library, i) or { continue }
		type_str := info.get_type()
		name := info.get_name()

		counts[type_str] = counts[type_str] + 1
		if entries_by_type[type_str].len < 3 {
			entries_by_type[type_str] << name
		}

		info.free()
	}

	// display summary by type
	println('\nContents:')
	for type_key in ['object', 'interface', 'struct', 'enum', 'flags', 'function', 'callback',
		'constant', 'union'] {
		if type_key in counts {
			count := counts[type_key]
			println('  ${type_key}: ${count}')
		}
	}
}
