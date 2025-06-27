use path;
use paths;
use paths::{abspathbuf};
use strings;

export type vfspathrepr = (abspathbuf | str);

export type vfspath = struct {
	path: vfspathrepr,
};

export fn newvfspath(path: vfspathrepr) vfspath = {
	match (path) {
	case let apb: abspathbuf =>
		assert(path::abs(&apb.buf));
	case let ps: str =>
		assert(strings::hasprefix(ps, "/"));
	};

	return vfspath {
		path = path,
	};
};

export fn vfspath_equals(vp0: *vfspath, vp1: *vfspath) bool = {
	match (vp0.path) {
	case let p0: abspathbuf =>
		match (vp1.path) {
		case str => return false;
		case let p1: abspathbuf =>
			return paths::string(&p0) == paths::string(&p1);
		};
	case => return false;
	};
};

export fn vfspath_string(vp: *vfspath) str =
	match (vp.path) {
	case let pb: abspathbuf =>
		yield paths::string(&pb);
	case let s: str =>
		yield s;
	};

export fn vfspath_dup(vp: *vfspath) vfspath = {
	let path = match (vp.path) {
	case let p: abspathbuf =>
		yield abspathbuf {
			buf = path::init(path::string(&p.buf))!,
		};
	case let p: str =>
		yield strings::dup(p)!;
	};
	return vfspath { path = path };
};
