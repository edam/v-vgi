module gen

import os

fn test_get_vmod_path_returns_non_empty() {
	path := get_vmod_path('')
	assert path != ''
}

fn test_get_vmod_path_finds_v_mod() {
	path := get_vmod_path('v.mod')
	assert os.exists(path), 'v.mod should exist at ${path}'
}

fn test_get_vmod_path_v_mod_is_file() {
	path := get_vmod_path('v.mod')
	assert os.is_file(path), '${path} should be a file'
}

fn test_get_vmod_path_empty_string() {
	path := get_vmod_path('')
	assert os.is_dir(path), 'empty path should return module directory'
}

fn test_get_vmod_path_subdirectory() {
	// test with a file we know exists in gen/ subdirectory
	path := get_vmod_path('gen/util.v')
	assert os.exists(path), 'gen/util.v should exist at ${path}'
	assert os.is_file(path), 'gen/util.v should be a file'
}

fn test_get_vmod_path_contains_vgi() {
	// The path should contain 'vgi' since this is the vgi module
	path := get_vmod_path('')
	assert path.contains('vgi'), 'module path should contain "vgi", got: ${path}'
}

fn test_get_vmod_path_multiple_files() {
	// test that we can locate multiple known files
	files := ['v.mod', 'gen/util.v', 'gen/gi.v', 'gen/compat.c.v']
	for file in files {
		path := get_vmod_path(file)
		assert os.exists(path), '${file} should exist at ${path}'
	}
}
