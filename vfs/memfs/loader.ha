use path;
use paths;
use paths::{abspathbuf};

export type entry = (
	// The `entry` is represented by a raw set of files.
	[]abspathbuf |
	// The `Entry` is represented by `Directories`.
	directories
);

export fn ha_files_recursively(base: abspathbuf) entry = {
	return dirs(base, &[".git"]);
};

/// Specifies a set of files on the file system.
///
/// A file is included if:
///   * it has included extension
///   * it is under an `include` path
///   * it is not under `exclude` path
///
/// If many include/exclude paths match, the longest one wins.
///
/// If a path is in both `include` and `exclude`, the `exclude` one wins.
export type directories = struct {
	extensions: []str,
	include: []abspathbuf,
	exclude: []abspathbuf,
};

fn dirs(base: abspathbuf, exclude: []str) directories = {
	let base = base;
	let exc: []abspathbuf = [];
	for (let e .. exclude) {
		append(exc, paths::from(path::push(&base, e)!))!;
	};
	return directories {
		extensions = ["ha"],
		include = [base],
		exclude = exc,
	};
};
