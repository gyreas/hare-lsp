use bytes;
use fmt;
use hash;
use hash::fnv;
use strings;

def FCFM_BUCKETS_COUNT: size = 32;

export type fileid_changedfile_map = struct {
	keys: [FCFM_BUCKETS_COUNT][]fileid,
	values: [FCFM_BUCKETS_COUNT][]changedfile,
};

fn fcfm_finish(hm: *fileid_changedfile_map) void = {
	for (let kb &.. hm.keys) free(kb);
	for (let vb &.. hm.keys) free(vb);
};

fn fcfm_hash(id: fileid) size = {
	let bytes = ((&id): *opaque: *[*]u8)[..size(fileid)];
	return fnv::string(strings::fromutf8_unsafe(bytes));
};

fn fcfm_get(hm: *fileid_changedfile_map, k: fileid) (*changedfile | void) = {
	let l = len(hm.keys);
	let h = fcfm_hash(k);
	let kbucket = &hm.keys[h % l];
	let vbucket = &hm.values[h % l];

	assert(len(kbucket) == len(vbucket));

	let l = len(kbucket);
	for (let i = 0z; i < l; i += 1) {
		if (kbucket[i]: u32 == k: u32) {
			return &vbucket[i];
		};
	};
};

fn fcfm_put(hm: *fileid_changedfile_map, k: fileid, v: changedfile) (changedfile | void) = {
	let l = len(hm.keys);
	let h = fcfm_hash(k);
	let kbucket = &hm.keys[h % l];
	let vbucket = &hm.values[h % l];

	assert(len(kbucket) == len(vbucket));

	let l = len(kbucket);
	for (let i = 0z; i < l; i += 1) {
		if (kbucket[i]: u32 == k: u32) {
			if (true) abort();
			let oldvalue = vbucket[i];
			vbucket[i] = v;
			return oldvalue;
		};
	};
	append(kbucket, k)!;
	append(vbucket, v)!;
};

fn fcfm_remove(hm: *fileid_changedfile_map, k: fileid) (changedfile | void) = {
	let l = len(hm.keys);
	let h = fcfm_hash(k);
	let kbucket = &hm.keys[h % l];
	let vbucket = &hm.values[h % l];

	assert(len(kbucket) == len(vbucket));

	let l = len(kbucket);
	for (let i = 0z; i < l; i += 1) {
		if (kbucket[i]: u32 == k: u32) {
			let v = vbucket[i];
			delete(kbucket[i]);
			delete(vbucket[i]);
			return v;
		};
	};
};

fn fcfm_haskey(hm: *fileid_changedfile_map, k: fileid) bool = {
	let kbucket = &hm.keys[fcfm_hash(k) % len(hm.keys)];
	for (let i = 0z; i < len(kbucket); i += 1) {
		if (kbucket[i]: u32 == k: u32) {
			return true;
		};
	};
	return false;
};
