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

	if opts.verbose {
		println('debug: printing message')
	}
}
