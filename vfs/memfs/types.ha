export type filestate = (exists | deleted);
export type exists = u64;
export type deleted = void;

export type filechange = (creation | modification | deletion);
export type modification = (str, u64);
export type creation = (str, u64);
export type deletion = void;

export type filechangekind = enum u8 {
	CREATION,
	MODIFICATION,
	DELETION,
};

export type changedfile = struct {
	fileid: fileid,
	change: filechange,
};

export fn changedfile_kind(cf: *changedfile) filechangekind = match (cf.change) {
	case creation => yield filechangekind::CREATION;
	case deletion => yield filechangekind::DELETION;
	case modification => yield filechangekind::MODIFICATION;
};
