use bytes;
use fmt;
use endian;
use hash;
use hash::fnv;
use memio;
use strings;
use vfs = vfs::memfs;
use vfs::memfs::{vfspath};

type memdocs = struct {
	docs: vfs_data_map, // vfspath => document_data
	count: size,
	added_or_removed: bool,
};

fn newmemdocs() memdocs = memdocs {
	docs = vfs_data_map { ... },
	count = 0,
	added_or_removed = false,
};

fn memdocs_contains(md: *memdocs, path: *vfspath) bool = {
	return hm_haskey(&md.docs, path);
};

export type memdocs_error = !void;

fn memdocs_count(md: *memdocs) size =
	md.count;

fn memdocs_get(md: *memdocs, path: *vfspath) (*document_data | void) =
	hm_get(&md.docs, path);

fn memdocs_insert(md: *memdocs, path: *vfspath, data: document_data) (void | memdocs_error) = {
	md.added_or_removed = true;
	match (hm_put(&md.docs, path, data)) {
	case document_data =>
		return memdocs_error; // already exist
	case void =>
		md.count += 1;
		return void;
	};
};

fn memdocs_remove(md: *memdocs, path: *vfspath) (void | memdocs_error) = {
	md.added_or_removed = true;
	match (hm_remove(&md.docs, path)) {
	case document_data =>
		md.count -= 1;
		return void;
	case void => return memdocs_error; // doesn't exist
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

fn docdata_string(dd: *document_data) str = {
	let buf = memio::dynamic();
	fmt::fprintfln(&buf, "Document {{\n\tversion: {}\n\tdata: \"{}\"\n}}", dd.version, dd.data)!;
	return memio::string(&buf)!;
};
