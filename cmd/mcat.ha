use fmt;
use fs;
use getopt;
use io;
use lsp::proto;
use memio;
use os;
use strings;

export fn main() void = {
	let cmd = getopt::parse(os::args,
		"mcat: generates LSP messages from JSON files and concatenate them into a single readable stream.",
		"[file.json...]",
	);
	defer getopt::finish(&cmd);

	if (len(cmd.args) == 0) {
		getopt::printusage(os::stderr, "mcat", cmd.help)!;
		return;
	};

	let stream = memio::dynamic();
	let buf = memio::dynamic();
	defer {
		free(memio::buffer(&buf));
		free(memio::buffer(&stream));
	};

	for (let path .. cmd.args) {
		let fd = match (os::open(path)) {
		case let e: fs::error =>
			fmt::fatalf("error opening '{}': {}", path, fs::strerror(e));
		case let fd: io::file =>
			yield fd;
		};

		// TODO: stat the file to get the size for allocation;

		let n = match (io::copy(&buf, fd)) {
		case let e: io::error =>
			fmt::fatalf("error reading '{}': {}", path, io::strerror(e));
		case let n: size => yield n;
		};
		let message = proto::message {
			headers = proto::headers {
				content_length = n,
				content_type = proto::HARELS_CONTENT_TYPE,
			},
			content = strings::fromutf8_unsafe(memio::buffer(&buf)[..n]),
		};
		proto::write(&stream, &message)!;
		memio::reset(&buf);
	};
	fmt::println(strings::fromutf8_unsafe(memio::buffer(&stream)))!;
};
