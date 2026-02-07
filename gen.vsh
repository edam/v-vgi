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
	ggetopt.opt('verbose', none).help('show debug information'),
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
	info    bool
	verbose bool
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
		'verbose' {
			o.verbose = true
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
		show_info(library, version, opts.verbose)
		exit(0)
	}

	// Generate bindings
	generate_bindings(library, version, opts.verbose)
}

fn get_binding_dir_name(library string, version string) string {
	// Convert "Gtk-4.0" to "gtk_4_0"
	lib_lower := library.to_lower().replace('-', '_')
	ver_lower := version.replace('.', '_').replace('-', '_')
	return '${lib_lower}_${ver_lower}'
}

fn generate_bindings(library string, version string, verbose bool) {
	repo := vgi.get_default_repository()

	// Load the library
	repo.require(library, version) or {
		eprintln('Error: Failed to load library ${library}-${version}')
		eprintln('${err}')
		exit(1)
	}

	if verbose {
		println('Loaded ${library}-${version}')
	}

	// Get directory name for bindings
	dir_name := get_binding_dir_name(library, version)
	binding_dir := vgi.get_vmod_path(dir_name)

	if verbose {
		println('Generating bindings in: ${binding_dir}')
	}

	// Create or empty the directory
	if os.exists(binding_dir) {
		if verbose {
			println('Directory exists, emptying it')
		}
		os.rmdir_all(binding_dir) or {
			eprintln('Error: Failed to remove existing directory ${binding_dir}')
			eprintln('${err}')
			exit(1)
		}
	}

	os.mkdir_all(binding_dir) or {
		eprintln('Error: Failed to create directory ${binding_dir}')
		eprintln('${err}')
		exit(1)
	}

	// Write README.md
	readme_path := os.join_path(binding_dir, 'README.md')
	typelib_path := repo.get_typelib_path(library)
	loaded_version := repo.get_version(library)

	readme_content := 'Library: ${library}
Typelib: ${typelib_path}
Version: ${loaded_version}
'

	os.write_file(readme_path, readme_content) or {
		eprintln('Error: Failed to write README.md')
		eprintln('${err}')
		exit(1)
	}

	if verbose {
		println('Wrote ${readme_path}')
	}

	println('Generated bindings for ${library}-${version} in ${dir_name}/')
}

fn show_info(library string, version string, verbose bool) {
	repo := vgi.get_default_repository()

	// Try to load the library
	repo.require(library, version) or {
		eprintln('Error: Failed to load library ${library}-${version}')
		eprintln('${err}')
		exit(1)
	}

	println('Library found: ${library}-${version}')

	// Get the typelib path
	path := repo.get_typelib_path(library)
	if path != '' {
		println('Typelib path: ${path}')
	}

	// Get the actual loaded version
	loaded_version := repo.get_version(library)
	if loaded_version != '' {
		println('Loaded version: ${loaded_version}')
	}

	// Get metadata count and iterate through entries
	n_infos := repo.get_n_infos(library)
	println('Metadata entries: ${n_infos}')

	// Collect entries by type
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

	// Display summary by type
	println('\nContents:')
	type_labels := {
		'object':    'objects'
		'interface': 'interfaces'
		'struct':    'structs'
		'enum':      'enums'
		'flags':     'flags'
		'function':  'functions'
		'callback':  'callbacks'
		'constant':  'constants'
		'union':     'unions'
	}

	for type_key in ['object', 'interface', 'struct', 'enum', 'flags', 'function', 'callback', 'constant', 'union'] {
		if type_key in counts {
			count := counts[type_key]
			examples := entries_by_type[type_key]
			label := type_labels[type_key]
			print('  ${label}: ${count}')
			if examples.len > 0 {
				print(' (e.g., ${examples.join(', ')}')
				if count > examples.len {
					print(', ...')
				}
				print(')')
			}
			println('')
		}
	}

	if verbose {
		println('\nDebug: Successfully loaded and queried ${library}-${version}')
	}
}
