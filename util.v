module vgi

import os

pub fn get_vmod_path(rel_path string) string {
	vmod_path := os.dir(@FILE)
	return os.join_path(vmod_path, rel_path)
}
