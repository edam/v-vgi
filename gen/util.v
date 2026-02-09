module gen

import os

pub fn get_vmod_path(rel_path string) string {
	// @FILE is in gen/ subdirectory, go up one level to module root
	gen_dir := os.dir(@FILE)
	vmod_path := os.dir(gen_dir)
	return os.join_path(vmod_path, rel_path)
}
