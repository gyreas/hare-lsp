use fmt;
use hash::fnv;
use strings;

def FILEID_MAX: u32 = 0x7fff_ffff;

export type fileid = u32;

export fn fileid_from(raw: u32) fileid = {
	assert(raw <= FILEID_MAX);
	return raw: u32;
};

export type memfs = struct {
	interner: pathinterner,
	data: fileid_filestate_map, // fileid => filestate
	changes: fileid_changedfile_map, // fileid => changedfile
};

export fn new() memfs = memfs {
	interner = pathinterner { ... },
	data = fileid_filestate_map {...},
	changes = fileid_changedfile_map {...},
};

export fn get_id_frompath(fs: *memfs, path: *vfspath) (fileid | void) = {
	let fileid = pi_get(&fs.interner, path) as fileid;
	match (get(fs, fileid)) {
	case exists => return fileid;
	case deleted => return void;
	};
};

export fn get_path_fromid(fs: *memfs, id: fileid) *vfspath = {
	return pi_lookup(&fs.interner, id);
};

export fn hasid(fs: *memfs, id: fileid) bool = {
	return get(fs, id) is exists;
};

export fn set_file_contents(fs: *memfs, path: *vfspath, contents: (str | void)) bool = {
	let fileid = allocate_fileid(fs, path);
	let state = get(fs, fileid);

	let change: filechange = match (state) {
	case deleted =>
		yield match (contents) {
		case void => return false;
		case let s: str =>
			yield (s, fnv::string64(s)): creation;
		};
	case let e: exists =>
		yield match (contents) {
		case void =>
			yield deletion;
		case let s: str =>
			let newhash = fnv::string64(s);
			if (newhash == e: u64) {
				return false;
			};
			yield (s, newhash): modification;
		};
	case => abort();
	};

	let changed_file = changedfile {
		fileid = fileid,
		change = change,
	};

	let change_kind = match (fcfm_get(&fs.changes, fileid)) {
	case let cf: *changedfile => // occupied
		match (&changed_file.change) {
		case let mod: *modification =>
			match (&cf.change) {
			case let cm: *(creation | modification) =>
				let cm = cm: *(str, u64);
				let mod = mod: *(str, u64);
				*cm = *mod;
			case => abort();
			};
		case let creat: *creation =>
			let creat = creat: *(str, u64);
			match (&cf.change) {
			case let c: *creation =>
				let c = c: *(str, u64);
				*c = *creat;
			case let m: *modification =>
				let m = m: *(str, u64);
				*m = *creat;
			case =>
				abort();
			};
		case deletion =>
			cf.change = deletion;
		};
		yield &cf.change;
	case void => // vacant
		yield &changed_file.change;
	};

	let state = match (change_kind) {
	case let c: *creation =>
		let c = c: *(str, u64);
		fmt::errorfln("[creat] putting content: '{}': {:x}", c.0, c.1)!;
		yield c.1: exists;
	case let m: *modification =>
		let m = m: *(str, u64);
		fmt::errorfln("[modif] putting content: '{}': {:x}", m.0, m.1)!;
		yield m.1: exists;
	case =>
		yield deleted;
	};

	ffm_put(&fs.data, fileid, state);
	return true;
};

fn allocate_fileid(fs: *memfs, path: *vfspath) fileid = {
	let file_id = pi_intern(&fs.interner, path);
	ffm_put(&fs.data, file_id, deleted);
	return file_id;
};

fn get(fs: *memfs, id: fileid) filestate = {
	return ffm_get(&fs.data, id) as filestate;
};
