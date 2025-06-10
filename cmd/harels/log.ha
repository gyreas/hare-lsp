use fmt;

fn loginfo(fmt: str, args: fmt::field...) void = {
	fmt::error("[INFO] ")!;
	fmt::errorfln(fmt, args...)!;
};
