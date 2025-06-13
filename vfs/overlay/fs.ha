use bufio;
use errors;
use fmt;
use fs;
use io;
use os;
use path;
use strings;

const vt: fs::fs = fs::fs {
	close = &close,
	create = &create,
	iter = &iter,
	mkdir = &mkdir,
	open = &open,
	readlink = &readlink,
	remove = &remove,
	resolve = &resolve,
	stat = &stat,
	...
};

export type overlayfs = struct {
	fs: fs::fs,
	under: *fs::fs,

	over_path: str,
	under_cwd: str,
};

export fn new(under_cwd: str, over_path: str) overlayfs = {
	let under = match (os::diropen(under_cwd)) {
	case let u: *fs::fs =>
		yield u;
	case let e: fs::error =>
		fmt::errorfln("error: {}", fs::strerror(e))!;
		abort("Unreachable");
	};
	return overlayfs {
		fs = vt,
		under = under,
		under_cwd = strings::dup(under_cwd)!,
		over_path = strings::dup(over_path)!,
	};
};

fn open(fs: *fs::fs, fpath: str, flag: fs::flag) (io::handle | fs::error) = {
	let fs = fs: *overlayfs;

	const overlay_path = path(fs, fpath);
	const err = match (fs::open(fs.under, overlay_path, flag)) {
	case let handle: io::handle =>
		return handle;
	case let err: fs::error =>
		yield err;
	};

	// Only the overlay can be written to
	if (flag & (fs::flag::WRONLY | fs::flag::RDWR) > 0) {
		return err;
	};

	// No entry is fine here because the file may not be in the overlay
	match (err) {
	case errors::noentry =>
		void;
	case =>
		return err;
	};

	return fs::open(fs.under, fpath, flag);
};

fn close(fs: *fs::fs) void = {
	let fs = fs: *overlayfs;

	fs::close(fs.under);
	free(fs.over_path);
	free(fs.under_cwd);
};

fn remove(fs: *fs::fs, fpath: str) (void | fs::error) = {
	let fs = fs: *overlayfs;

	// Only overlay can be edited
	const overlay_path = path(fs, fpath);
	return fs::remove(fs.under, overlay_path);
};

fn create(fs: *fs::fs, fpath: str, mode: fs::mode, flag: fs::flag) (io::handle | fs::error) = {
	let fs = fs: *overlayfs;

	// Only overlay can be edited
	const overlay_path = path(fs, fpath);
	return fs::create(fs.under, overlay_path, mode, flag);
};

fn mkdir(fs: *fs::fs, fpath: str, mode: fs::mode) (void | fs::error) = {
	let fs = fs: *overlayfs;

	// Only overlay can be edited
	const overlay_path = path(fs, fpath);
	return fs::mkdir(fs.under, overlay_path, mode);
};

fn iter(fs: *fs::fs, fpath: str) (*fs::iterator | fs::error) = {
	let fs = fs: *overlayfs;

	const overlay_path = path(fs, fpath);
	let over = match (fs::iter(fs.under, overlay_path)) {
	case let over: *fs::iterator =>
		yield over;
	case fs::error =>
		yield null;
	};

	let iter = alloc(iterator { iter = iter_vt, over = over })!;

	return iter;
};

fn resolve(fs: *fs::fs, fpath: str) str = {
	let fs = fs: *overlayfs;
	return fs::resolve(fs.under, fpath);
};

fn stat(fs: *fs::fs, fpath: str) (fs::filestat | fs::error) = {
	let fs = fs: *overlayfs;

	const overlay_path = path(fs, fpath);
	match (fs::stat(fs.under, overlay_path)) {
	case let filestat: fs::filestat =>
		return filestat;
	case let err: fs::error =>
		match (err) {
		case errors::noentry =>
			void;
		case =>
			return err;
		};
	};

	return fs::stat(fs.under, fpath);
};

fn readlink(fs: *fs::fs, fpath: str) (str | fs::error) = {
	let fs = fs: *overlayfs;
	// TODO: Deal with overlay
	return fs::readlink(fs.under, fpath);
};

fn path(fs: *overlayfs, fpath: str) str = {
	static let buf = path::buffer { ... };
	// I'm using this without extra processing since fs:: functions take the fs as
	// argument, thus it already has the rootest path on it, somewhat
	path::set(&buf, fs.over_path, fpath)!;
	return path::string(&buf);
};

// @test fn overlayfs() void = {
// 	// let under = os::diropen("/tmp/a")!;
// 	let overlayfs = new("underfs", "upthre");
// 	let iter = fs::iter(&overlayfs, ".")!;
// 	defer fs::finish(iter);

// 	for (true) match (fs::next(iter)) {
// 	case done => abort();
// 	case let err: fs::error =>
// 		fmt::errorfln("error: {}", fs::strerror(err))!;
// 		abort();
// 	case let dirent: fs::dirent =>
// 		let n = dirent.name;
// 		// match (fmt::printfln("dirent: {}", n)) {
// 		// case size => void;
// 		// case let e: io::error =>
// 		// 	// abort("ddidi");
// 		// 	void;
// 		// };
// 	};
// 	// abort();

// 	// fs::stat(&overlayfs, "/tmp/b/ccc")!;
// };
