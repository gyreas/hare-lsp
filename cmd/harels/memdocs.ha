use bytes;
use fmt;
use endian;
use hash;
use hash::fnv;
use strings;
use vfs = vfs::memfs;
use vfs::memfs::{vfspath};

type memdocs = struct {
	docs: vfs_data_map, // vfspath => document_data
	added_or_removed: bool,
};

fn newmemdocs() memdocs = memdocs {
	docs = vfs_data_map { ... },
	added_or_removed = false,
};

fn memdocs_contains(md: *memdocs, path: *vfspath) bool = {
	return hm_haskey(&md.docs, path);
};

export type error = !void;

fn memdocs_get(md: *memdocs, path: *vfspath) (document_data | void) =
	hm_get(&md.docs, path);

fn memdocs_insert(md: *memdocs, path: *vfspath, data: document_data) (void | error) = {
	md.added_or_removed = true;
	match (hm_put(&md.docs, path, data)) {
	case document_data =>
		return error;
	case void =>
		return void;
	};
};

fn memdocs_remove(md: *memdocs, path: *vfspath) (void | error) = {
	md.added_or_removed = true;
	match (hm_remove(&md.docs, path)) {
	case document_data => return void;
	case void => return error;
	};
};

type document_data = struct {
	version: i32,
	data: str,
};

fn newdocdata(v: i32, data: str) document_data =
	document_data {
		version = v,
		data = strings::dup(data)!,
	};
