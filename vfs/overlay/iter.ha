use fs;
use fmt;
use strings;

type iterator = struct {
	iter: fs::iterator,
	
	over: nullable *fs::iterator,
};

const iter_vt: fs::iterator = fs::iterator {
	next = &iter_next,
	finish = &iter_finish,
};

fn iter_next(iter: *fs::iterator) (fs::dirent | fs::error | done) = {
	let iter = iter: *iterator; 

	match (iter.over) {
	case null => return done;
	case let over: *fs::iterator =>
		match (fs::next(over)?) {
		case let dirent: fs::dirent =>
			return dirent;
		case done =>
			return done;
		};
	};

};

fn iter_finish(iter: *fs::iterator) void = {
	let iter = iter: *iterator;

	match (iter.over) {
	case let over: *fs::iterator =>
		fs::finish(over);
	case null => void;
	};

	free(iter);
};
