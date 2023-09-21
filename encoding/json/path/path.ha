// A compiled JSONPath query.
export type query = []segment;

export type segment_type = enum {
	CHILD,
	DESCENDANT,
};

export type segment = struct {
	stype: segment_type,
	selector: selector,
};

export type selector = (str | wild | index | slice | filter);

export type wild = void;

export type index = int;

export type slice = struct {
	start: (int | void),
	end: (int | void),
	step: (int | void),
};

export type filter = void; // TODO
