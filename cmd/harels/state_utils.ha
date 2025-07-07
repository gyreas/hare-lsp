use bytes;
use encoding::hex;
use fmt;
use lsp;
use memio;
use strings;

fn apply_document_changes(contents: str, content_changes: []lsp::text_document_content_change_event) str = {
	// find the last (most recent) full text change (one with missing [[range]] field),
	// and use it as base for subsequent changes
	let (contents, content_changes) = (contents, content_changes);
	for (let i = 1z; i <= len(content_changes); i += 1) {
		let j = len(content_changes) - i;
		let content_change = &content_changes[j];
		if (content_change.range is void) {
			// TODO: handle versioning
			free(contents);
			contents = content_change.text;
			content_changes = content_changes[j + 1..];
			break;
		};
	};

	// TODO: use a better string API for this, the allocations are too erratic
	for (let content_change &.. content_changes) {
		let range = range_string(content_change.range as lsp::range);
		let (bytestart, byteend)= byteoffset_fromrange(content_change.range as lsp::range, contents);
		loginfo("[didChange] range: {}, byteoffset: ({}, {})", range, bytestart, byteend);

		let newdata = if (bytestart >= len(contents)) {
			yield strings::concat(contents, content_change.text)!;
		} else if (bytestart == byteend){
			let sbytes = strings::toutf8(contents);

			let bytes: []u8 = alloc([], len(contents)+len(content_change.text))!;
			static append(bytes, sbytes[..bytestart]...)!;
			static append(bytes, strings::toutf8(content_change.text)...)!;
			static append(bytes, sbytes[bytestart..]...)!;

			let sub = strings::fromutf8_unsafe(bytes);
			loginfo("[didChange] sub: '{}'", sub);
			yield sub;
		} else {
			let sub = strings::sub(contents, bytestart, byteend);
			loginfo("[didChange] sub: '{}'", sub);
			yield replace_range(contents, bytestart, byteend, content_change.text);
		};
		loginfo("[didChange] new: '{}'", newdata);

		free(contents);
		contents = newdata;
	};

	return contents;
};

fn replace_range(s: str, start: size, end: (size | strings::end), with: str) str = {
	let end = if (end is strings::end) len(s) - 1 else end as size;
	assert(end >= start);

	let s = strings::toutf8(s);
	let rangelen = end - start;
	let sslen = if (len(with) >= rangelen) len(s) + (len(with) - rangelen)
	else len(s) - (rangelen - len(with));

	let ss: []u8 = alloc([], sslen)!;
	static append(ss, s[..start]...)!;
	static append(ss, strings::toutf8(with)...)!;
	static append(ss, s[end..]...)!;
	assert(len(ss) == sslen);

	return strings::fromutf8(ss)!;
};

@test fn apply_document_changes() void = {
	let text = apply_document_changes(strings::dup("")!, []);
	assert_eq(text, "");
	let text = apply_document_changes(text, [lsp::text_document_content_change_event {
		text = strings::dup("the")!,
		range = void,
	}]);
	assert_eq(text, "the");
	let text = apply_document_changes(text, cs(((0,3), (0,3), " quick")));
	assert_eq(text, "the quick");
	let text = apply_document_changes(text, cs([((0,0), (0,4), ""), ((0,5), (0,5), " foxes")]...));
	assert_eq(text, "quick foxes");
	let text = apply_document_changes(text, cs(((0,11), (0,11), "\ndream")));
	assert_eq(text, "quick foxes\ndream");
	let text = apply_document_changes(text, cs(((1,0), (1,0), "have ")));
	assert_eq(text, "quick foxes\nhave dream");
	let text = apply_document_changes(text, cs([
		((0,0), (0,0), "the "),
		((1,4), (1,4), " quiet"),
		((1,16), (1,16), "s\n")
	]...));
	assert_eq(text, "the quick foxes\nhave quiet dreams\n");
	let text = apply_document_changes(text, cs([((0,15), (0,15), "\n"), ((2,17), (2,17), "\n")]...));
	assert_eq(text, "the quick foxes\n\nhave quiet dreams\n\n");
	let text = apply_document_changes(text, cs([
		((1,0), (1,0), "DREAM"),
		((2,0), (2,0), "they "),
		((3,0), (3,0), "DON'T THEY?")
	]...));
	assert_eq(text, "the quick foxes\nDREAM\nthey have quiet dreams\nDON'T THEY?\n");
	let text = apply_document_changes(text, cs([((0,10), (1,5), ""), ((2,0), (2,12), "")]...));
	assert_eq(text, "the quick \nthey have quiet dreams\n");

	let text = strings::dup("🖤")!;
	let text = apply_document_changes(text, cs(((0,0), (0,0), "a")));
	assert_eq(text, "a🖤");

	// TODO:
	// 
	// let text = strings::dup("a\nb")!;
	// let text = apply_document_changes(text, cs([((0,1), (1,0), "\nțc"), ((0,1), (1,1), "d")]...));
	// assert_eq(text, "adcb");
	// 
	// let text = strings::dup("a\nb")!;
	// let text = apply_document_changes(text, cs([((0,1), (1,0), "ț\nc"), ((0,2), (0,2), "c")]...));
	// assert_eq(text, "ațc\ncb");
};

fn assert_eq(got: str, want: str) void = {
	if (want != got) {
		fmt::errorfln("=== want '{}'\n=== got '{}'", want, got)!;
		abort();
	};
};

fn cs(changes: ((u32, u32), (u32, u32), str)...) []lsp::text_document_content_change_event = {
	let content_changes = alloc([]: []lsp::text_document_content_change_event, len(changes))!;
	for (let (start, end, change) .. changes) {
		append(content_changes, lsp::text_document_content_change_event {
			text = change,
			range = lsp::range {
				start = lsp::position { line = start.0, character = start.1 },
				end = lsp::position { line = end.0, character = end.1 },
			},
		})!;
	};
	return content_changes;
};

fn position_string(p: lsp::position) str = {
	let buf = memio::dynamic();
	fmt::fprintf(&buf, "({}, {})", p.line, p.character)!;
	return memio::string(&buf)!;
};

fn position_equal(p0: lsp::position, p1: lsp::position) bool =
	p0.line == p1.line && p0.character == p1.character;

fn assert_range_eq(r0: lsp::range, r1: lsp::range) void = {
	if (position_equal(r0.start, r1.start)) {
		fmt::errorfln("=== want {}\n=== got {}", position_string(r0.start), position_string(r1.start))!;
		abort();
	};
	if (position_equal(r0.end, r1.end)) {
		fmt::errorfln("=== want {}\n=== got {}", position_string(r0.end), position_string(r1.end))!;
		abort();
	};
};

fn range_string(r: lsp::range) str = {
	let buf = memio::dynamic();
	fmt::fprintf(&buf, "Range [start: {}, end: {}]",
		position_string(r.start), position_string(r.end))!;
	return memio::string(&buf)!;
};

fn byteoffset_fromrange(range: lsp::range, s: str) (size, size) = {
	let (sl, sc) = (range.start.line, range.start.character);
	let (el, ec) = (range.end.line, range.end.character);

	let bytes = strings::toutf8(s);
	let lineindex = 0z;
	let offs = 0z;
	for (true) match (bytes::index(bytes[offs..], '\n')) {
	case let index: size =>
		fmt::errorfln("[st] off={}", offs)!;
		if (sl == lineindex) {
			break;
		} else {
			offs += index + 1;
			lineindex += 1;
		};
	case void =>
		break;
	};
	fmt::errorfln("start-offs={}", offs)!;
	let start = offs + sc;

	for (true) match (bytes::index(bytes[offs..], '\n')) {
	case let index: size =>
		fmt::errorfln("[en] off={}", offs)!;
		if (el == lineindex) {
			break;
		} else {
			offs += index + 1;
			lineindex += 1;
		};
	case void => break;
	};
	fmt::errorfln("end-offs={}", offs)!;
	let end = offs + ec;

	return (start, end);
};

fn assert_offset(o0: (size, size), o1: (size, size)) void = {
	if (o0.0 != o1.0) {
		fmt::errorfln("start:\n=== want {}\n=== got {}", o0.0, o1.0)!;
		abort();
	};
	if (o0.1 != o1.1) {
		fmt::errorfln("end:\n=== want {}\n=== got {}", o0.1, o1.1)!;
		abort();
	};
};

fn rn(s: (u32, u32), e: (u32, u32)) lsp::range = lsp::range {
	start = lsp::position { line = s.0, character = s.1 },
	end = lsp::position { line = e.0, character = e.1 },
};

@test fn byteoffset_fromrange() void = {
	let text = "Text";
	assert_offset(byteoffset_fromrange(rn((0, 4), (0, 4)), text), (4, 4));    // "This"

	let text = "This is acting\n\nS\ni\na";
	assert_offset(byteoffset_fromrange(rn((0, 0), (0, 3)), text), (0, 3));    // "This"
	assert_offset(byteoffset_fromrange(rn((0, 4), (0, 7)), text), (4, 7));    // " is "
	assert_offset(byteoffset_fromrange(rn((0, 8), (0, 13)), text), (8, 13));  // "acting"
	assert_offset(byteoffset_fromrange(rn((0, 13), (1, 0)), text), (13, 15)); // "g\n"
	assert_offset(byteoffset_fromrange(rn((0, 13), (2, 0)), text), (13, 16)); // "g\n\n"
	assert_offset(byteoffset_fromrange(rn((1, 0), (3, 0)), text), (15, 18));  // "\nS\n"
	assert_offset(byteoffset_fromrange(rn((3, 0), (4, 0)), text), (18, 20));  // "\ni\n"
	assert_offset(byteoffset_fromrange(rn((2, 0), (4, 1)), text), (16, 21));  // "S\ni\na"
	assert_offset(byteoffset_fromrange(rn((0, 0), (0, 13)), text), (0, 13));  // "This is acting"

	let text = "quick\nbrown\nfox";
	assert_offset(byteoffset_fromrange(rn((0, 1), (0, 3)), text), (1, 3));   // "uic"
	assert_offset(byteoffset_fromrange(rn((0, 1), (1, 0)), text), (1, 6));   // "uick\nb"
	assert_offset(byteoffset_fromrange(rn((0, 4), (1, 4)), text), (4, 10));  // "k\nbrown"
	assert_offset(byteoffset_fromrange(rn((0, 4), (1, 0)), text), (4, 6));   // "k\nb"
	assert_offset(byteoffset_fromrange(rn((1, 4), (2, 0)), text), (10, 12)); // "n\nf"
	assert_offset(byteoffset_fromrange(rn((2, 0), (2, 2)), text), (12, 14)); // "fox"
	assert_offset(byteoffset_fromrange(rn((0, 4), (2, 0)), text), (4, 12));  // "k\nbrown\nf"
	assert_offset(byteoffset_fromrange(rn((0, 0), (2, 2)), text), (0, 14));  // "quick\nbrown\nfox"
};

