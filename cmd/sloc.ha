use bytes;
use bufio;
use fmt;
use fs;
use io;
use memio;
use os;
use path;
use regex;
use sort;
use sort::cmp;
use strings;
use time;

type linecounter = struct {
	entries: [](str, u32, f64),
	lines: u32,
	maxwidth: size,
};

fn entrycmp(a: const *opaque, b: const *opaque) int = {
	let a = a: *(str, u32, f64);
	let b = b: *(str, u32, f64);
	return cmp::strs(&a.0, &b.0);
};

export fn main() void = {
	static let dirs = [
		"cmd/harels",
		"lsp/",
		"paths/",
		"rpc/",
		"vfs/memfs/",
	];
	static let path = path::buffer{...};

	let counter = linecounter {
		...
	};
	defer free(counter.entries);

	for (let dir .. dirs) {
		visitdir(dir, &path, &counter, []);
	};

	let mods = fmt::mods {
		alignment = fmt::alignment::CENTER,
		width = counter.maxwidth + 4,
		pad = ' ',
		...
	};

	let filename_mods = fmt::mods{
		width = mods.width - 2,
		alignment = mods.alignment,
		pad = ' ',
		...
	};

	fmt::printfln("{%}{:=8}{:7}\n", "filename", &filename_mods, "lines", "took")!;
	sort::sort(counter.entries, size((str, u32, f64)), &entrycmp)!;
	for (let (entry, linecount, duration) .. counter.entries) {
		fmt::printfln("{%} {:-5}  {:2f} ms", entry, &mods, linecount, duration)!;
	};

	fmt::printfln("\ntotal = {}", counter.lines)!;
};

fn countlines(path: str) u32 = {
	let file = os::open(path)!;
	defer io::close(file)!;

	let linecount = 0u32;
	for (true) match (bufio::read_line(file)!) {
	case let line: []u8 =>
		let trimmed = bytes::ltrim(line, ['\t', ' ']...);
		if (len(trimmed) == 0 || bytes::hasprefix(trimmed, ['/', '/'])) {
			// skip empty line and comment line
			continue;
		};
		linecount += 1;
	case io::EOF => break;
	};
	return linecount;
};

fn visitdir(currentdir: str, path: *path::buffer, counter: *linecounter, pending_dirs: []str) void = {
	let it = os::iter(currentdir)!;
	defer fs::finish(it);
	for (let entry => fs::next(it)!) {
		let entrypath = path::set(path, currentdir, entry.name)!;
		if (fs::isfile(entry.ftype)) {
			match (path::peek_ext(path)) {
			case let ext: str => if (ext != "ha") continue;
			case void => continue;
			};

			let	s = time::now(time::clock::MONOTONIC),
				linecount = countlines(entrypath),
				e = time::now(time::clock::MONOTONIC),
				duration = time::diff(s, e)/time::MILLISECOND + 8,
				len_entrypath = len(entrypath);

			if (len_entrypath > counter.maxwidth) {
				counter.maxwidth = len_entrypath;
			};
			counter.lines += linecount;

			append(counter.entries, (strings::dup(entrypath)!, linecount, duration: f64))!;
		} else if (fs::isdir(entry.ftype)) {
			append(pending_dirs, strings::dup(entrypath)!)!;
		} else abort();
	};

	defer strings::freeall(pending_dirs);
	for (let pending_dir .. pending_dirs) {
		visitdir(pending_dir, path, counter, []);
	};
};
