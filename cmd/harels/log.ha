use fmt;

fn logerr(fmt: str, args: fmt::field...) void = {
	fmt::error("[ERROR] ")!;
	fmt::errorfln(fmt, args...)!;
};

fn loginfo(fmt: str, args: fmt::field...) void = {
	fmt::error("[INFO] ")!;
	fmt::errorfln(fmt, args...)!;
};
