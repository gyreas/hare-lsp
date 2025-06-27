use bytes;
use fmt;
use hash;
use hash::fnv;
use strings;

def BUCKETS_COUNT: size = 32;

export type fileid_filestate_map = struct {
	keys: [BUCKETS_COUNT][]fileid,
	values: [BUCKETS_COUNT][]filestate,
};

fn ffm_finish(hm: *fileid_filestate_map) void = {
	for (let kb &.. hm.keys) free(kb);
	for (let vb &.. hm.keys) free(vb);
};

fn ffm_hash(id: fileid) size = {
	let bytes = ((&id): *opaque: *[*]u8)[..size(fileid)];
	return fnv::string(strings::fromutf8_unsafe(bytes));
};

fn ffm_get(hm: *fileid_filestate_map, k: fileid) (filestate | void) = {
	let l = len(hm.keys);
	let h = ffm_hash(k);
	let kbucket = &hm.keys[h % l];
	let vbucket = &hm.values[h % l];

	assert(len(kbucket) == len(vbucket));

	let l = len(kbucket);
	for (let i = 0z; i < l; i += 1) {
		if (kbucket[i]: u32 == k: u32) {
			return vbucket[i];
		};
	};
};

fn ffm_put(hm: *fileid_filestate_map, k: fileid, v: filestate) (filestate | void) = {
	let l = len(hm.keys);
	let h = ffm_hash(k);
	let kbucket = &hm.keys[h % l];
	let vbucket = &hm.values[h % l];

	assert(len(kbucket) == len(vbucket));

	let l = len(kbucket);
	for (let i = 0z; i < l; i += 1) {
		if (kbucket[i]: u32 == k: u32) {
			let oldvalue = vbucket[i];
			vbucket[i] = v;
			return oldvalue;
		};
	};
	append(kbucket, k)!;
	append(vbucket, v)!;
};

fn ffm_remove(hm: *fileid_filestate_map, k: fileid) (filestate | void) = {
	let l = len(hm.keys);
	let h = ffm_hash(k);
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

fn ffm_haskey(hm: *fileid_filestate_map, k: fileid) bool = {
	let kbucket = &hm.keys[ffm_hash(k) % len(hm.keys)];
	for (let i = 0z; i < len(kbucket); i += 1) {
		if (kbucket[i]: u32 == k: u32) {
			return true;
		};
	};
	return false;
};
