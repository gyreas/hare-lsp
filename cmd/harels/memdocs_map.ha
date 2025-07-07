use bytes;
use fmt;
use hash;
use hash::fnv;
use strings;
use vfs = vfs::memfs;
use vfs::memfs::{vfspath};

def BUCKETS_COUNT: size = 32;

type vfs_data_map = struct {
	keys: [BUCKETS_COUNT][]vfspath,
	values: [BUCKETS_COUNT][]document_data,
};

fn hm_finish(hm: *vfs_data_map) void = {
	for (let kb &.. hm.keys) free(kb);
	for (let vb &.. hm.keys) free(vb);
};

fn hash(key: *vfspath) size =
	fnv::string(vfs::vfspath_string(key));

fn hm_get(hm: *vfs_data_map, k: *vfspath) (*document_data | void) = {
	let l = len(hm.keys);
	let h = hash(k);
	let kbucket = &hm.keys[h % l];
	let vbucket = &hm.values[h % l];

	assert(len(kbucket) == len(vbucket));

	let l = len(kbucket);
	for (let i = 0z; i < l; i += 1) {
		if (vfs::vfspath_equals(&kbucket[i], k)) {
			return &vbucket[i];
		};
	};
};

fn hm_put(hm: *vfs_data_map, k: *vfspath, v: document_data) (document_data | void) = {
	let l = len(hm.keys);
	let h = hash(k);
	let kbucket = &hm.keys[h % l];
	let vbucket = &hm.values[h % l];

	assert(len(kbucket) == len(vbucket));

	let l = len(kbucket);
	for (let i = 0z; i < l; i += 1) {
		if (vfs::vfspath_equals(&kbucket[i], k)) {
			let oldvalue = vbucket[i];
			vbucket[i] = v;
			assert(oldvalue.version != vbucket[i].version);
			assert(oldvalue.data != vbucket[i].data);
			return oldvalue;
		};
	};
	append(kbucket, *k)!;
	append(vbucket, v)!;
};

fn hm_remove(hm: *vfs_data_map, k: *vfspath) (document_data | void) = {
	let l = len(hm.keys);
	let h = hash(k);
	let kbucket = &hm.keys[h % l];
	let vbucket = &hm.values[h % l];

	assert(len(kbucket) == len(vbucket));

	let l = len(kbucket);
	for (let i = 0z; i < l; i += 1) {
		if (vfs::vfspath_equals(&kbucket[i], k)) {
			let v = vbucket[i];
			delete(kbucket[i]);
			delete(vbucket[i]);
			return v;
		};
	};
};

fn hm_haskey(hm: *vfs_data_map, k: *vfspath) bool = {
	let kbucket = &hm.keys[hash(k) % len(hm.keys)];
	for (let i = 0z; i < len(kbucket); i += 1) {
		if (vfs::vfspath_equals(&kbucket[i], k)) {
			return true;
		};
	};
	return false;
};
