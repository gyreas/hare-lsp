use fmt;
use hash::fnv;
use strings;
use types;

// TODO: Resize table as appropriate
def PI_BUCKETS: size      = 32;
def PI_BUCKETS_BITS: size = 5;
def PI_BUCKETS_MAX: size  = (1 << PI_BUCKETS_BITS) - 1;
def PI_INDEX_BITS: size   = PI_BUCKETS - PI_BUCKETS_BITS;
def PI_INDEX_MAX: size    = (1 << PI_INDEX_BITS) - 1;

export type pathinterner = struct {
	buckets: [PI_BUCKETS][]vfspath,
	count: size,
};

export fn pi_finish(im: *pathinterner) void = {
	for (let bucket .. im.buckets) {
		for (let vpath .. bucket) match (vpath.path) {
		case let s: str => free(s);
		case => void;
		};
		free(bucket);
	};
};

fn indexfrom(buckidx: size, keyidx: size) fileid =
	((keyidx << PI_BUCKETS_BITS) | buckidx): fileid;

fn hash(key: *vfspath) size =
	fnv::string(vfspath_string(key));

export fn pi_get(im: *pathinterner, key: *vfspath) (fileid | void) = {
	const h = hash(key);
	const bucket_index = h % len(im.buckets);
	const bucket = &im.buckets[bucket_index];

	assert(len(bucket) < PI_INDEX_MAX);

	for (let i = 0z; i < len(bucket); i += 1) {
		if (vfspath_equals(&bucket[i], key)) {
			return indexfrom(bucket_index, i);
		};
	};
};

export fn pi_intern(im: *pathinterner, key: *vfspath) fileid = {
	const h = hash(key);
	const bucket_index = h % len(im.buckets);
	const bucket = &im.buckets[bucket_index];

	for (let i = 0z; i < len(bucket); i += 1) {
		if (vfspath_equals(&bucket[i], key)) {
			let id = indexfrom(bucket_index, i);
			assert(id < types::U32_MAX);
			return id;
		};
	};
	im.count += 1;

	append(bucket, vfspath_dup(key))!;

	return indexfrom(bucket_index, len(bucket)-1);
};

export fn pi_lookup(im: *pathinterner, index: fileid) *vfspath = {
	let bucket_index = index & PI_BUCKETS_MAX;
	let key_index = (index >> PI_BUCKETS_BITS) & PI_INDEX_MAX;
	let key = &im.buckets[bucket_index][key_index];
	// fmt::printfln("[lookup] bucket index = {0:b}/{0}, key index = {1:b}/{1}, key = {}, index = {:b}",
	// 	bucket_index, key_index, key, index: u32
	// )!;
	return key;
};

// iterator

export type pi_iterator = struct {
	im: *pathinterner,
	i: size,
	j: size,
};

export fn pi_iter(im: *pathinterner) pi_iterator =
	pi_iterator { im = im, ... };

export fn pi_next(iter: *pi_iterator) ((*vfspath, fileid) | done) = {
	for (iter.i < len(iter.im.buckets); iter.i += 1) {
		const bucket = &iter.im.buckets[iter.i];
		for (iter.j < len(bucket)) {
			let key = &bucket[iter.j];
			iter.j += 1;
			return (key, indexfrom(iter.i, iter.j - 1));
		};
		iter.j = 0;
	};
	return done;
};
