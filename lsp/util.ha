use encoding::json;

fn getarray(obj: *json::object, key: str) ([]json::value | deserialize_error) = {
	match (tryarray(obj, key)) {
	case let array: []json::value =>
		return array;
	case =>
		return stopbuggingmeerr;
	};
};

fn tryarray(obj: *json::object, key: str) ([]json::value | void | deserialize_error) = {
	match (json::get(obj, key)) {
	case let val: *json::value =>
		match (*val) {
		case let array: []json::value =>
			return array;
		case =>
			return stopbuggingmeerr;
		};
	case void => void;
	};
};

fn getobject(obj: *json::object, key: str) (json::object | deserialize_error) = {
	match (tryobject(obj, key)) {
	case let obj: json::object =>
		return obj;
	case =>
		return stopbuggingmeerr;
	};
};

fn tryobject(obj: *json::object, key: str) (json::object | void | deserialize_error) = {
	match (json::get(obj, key)) {
	case let val: *json::value =>
		match (*val) {
		case let obj: json::object =>
			return obj;
		case =>
			return stopbuggingmeerr;
		};
	case void => void;
	};
};

fn trybool(obj: *json::object, key: str) (bool | void | deserialize_error) = {
	match (json::get(obj, key)) {
	case let val: *json::value =>
		match (*val) {
		case let b: bool =>
			return b;
		case =>
			return stopbuggingmeerr;
		};
	case void => void;
	};
};

fn getstr(obj: *json::object, key: str) (str | deserialize_error) = {
	match (trystr(obj, key)?) {
	case let s: str => return s;
	case => return stopbuggingmeerr;
	};
};

fn trystr(obj: *json::object, key: str) (str | void | deserialize_error) = {
	match (trystrnull(obj, key)?) {
	case let val: (str | void) =>
		return val;
	case json::_null =>
		return stopbuggingmeerr;
	};
};

fn trystrnull(obj: *json::object, key: str) (str | json::_null | void | deserialize_error) = {
	match (json::get(obj, key)) {
	case let val: *json::value =>
		match (*val) {
		case let s: str =>
			return s;
		case json::_null =>
			return json::_null;
		case =>
			return stopbuggingmeerr;
		};
	case void => void;
	};
};

fn tryint(obj: *json::object, key: str) (i32 | void | deserialize_error) = {
	match (tryintnull(obj, key)?) {
	case let val: (i32 | void) =>
		return val;
	case json::_null =>
		return stopbuggingmeerr;
	};
};

fn tryintnull(obj: *json::object, key: str) (i32 | json::_null | void | deserialize_error) = {
	match (json::get(obj, key)) {
	case let val: *json::value =>
		match (*val) {
		case let f: f64 =>
			return f: i32;
		case json::_null =>
			return json::_null;
		case =>
			return stopbuggingmeerr;
		};
	case void => void;
	};
};

fn getfloat(obj: *json::object, key: str) (f64 | deserialize_error) = {
	match (tryfloat(obj, key)?) {
	case let val: f64 =>
		return val;
	case =>
		return stopbuggingmeerr;
	};
};

fn tryfloat(obj: *json::object, key: str) (f64 | void | deserialize_error) = {
	match (tryfloatnull(obj, key)?) {
	case let val: (f64 | void) =>
		return val;
	case json::_null =>
		return stopbuggingmeerr;
	};
};

fn tryfloatnull(obj: *json::object, key: str) (f64 | json::_null | void | deserialize_error) = {
	match (json::get(obj, key)) {
	case let val: *json::value =>
		match (*val) {
		case let f: f64 =>
			return f;
		case json::_null =>
			return json::_null;
		case =>
			return stopbuggingmeerr;
		};
	case void => void;
	};
};

export fn strfield(field: (str | json::_null | void)) str = {
	match (field) {
	case let s: str =>
		return s;
	case json::_null =>
		return "null";
	case void =>
		return "absent";
	};
};
