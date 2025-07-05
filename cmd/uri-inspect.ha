use fmt;
use getopt;
use net::ip;
use net::uri;
use os;

export fn main() void = {
	let cmd = getopt::parse(os::args,
		"disassemble a URI",
		"[uri...]",
	);

	if (len(cmd.args) == 0) {
		fmt::errorln("error: expected a URI")!;
		getopt::printusage(os::stderr, "uri-inspect", cmd.help)!;
	};

	for (let arg .. cmd.args) {
		let u = match (uri::parse(arg)) {
		case let u: uri::uri =>
			yield u;
		case uri::invalid =>
			fmt::errorfln("error: invalid URI: {}", arg)!;
			continue;
		};

		let host = match (u.host) {
		case let s: str => yield s;
		case => abort("unimp");
		};
		fmt::printfln("[{}]\n\tscheme {}\n\thost   {}\n\tpath   {}", arg, u.scheme, host, u.path)!;
	};
};
