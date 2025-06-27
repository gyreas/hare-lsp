//! Analysis-level representation of file-system paths.
//!
//! The primary goal of this is to losslessly represent paths like
//!
//! ```ignore
//! #[path = "./bar.ha"]
//! mod foo;
//! ```
//!
//! The second try is to use a `String`. This also fails, however. Consider a
//! hypothetical scenario, where [[harels]] operates in a
//! networked/distributed mode. There's one global instance of [[harels]],
//! which processes requests from different machines. Now, the semantics of
//! `#[path = "/abs/path.ha"]` actually depends on which file-system we are at!
//! That is, even absolute paths exist relative to a file system!
//!
//! A more realistic scenario here is virtual VFS paths we use for testing. More
//! generally, there can be separate "universes" of VFS paths.
//!
//! That's why we use anchored representation -- each path carries an info about
//! a file this path originates from. We can fetch fs/"universe" information
//! from the anchor than.

// Path relative to a file
//
// Owned verison of [[anchored_path]]
export type anchored_pathbuf = struct {
	// file that this path is relative to
	anchor: fileid,
	// path relative to [[anchor]]'s containiing directory
	path: str,
};

// Path relative to a file
//
// Borrowed version of [[anchored_pathbuf]]
export type anchored_path = struct {
	// file that this path is relative to
	anchor: fileid,
	// path relative to [[anchor]]'s containiing directory
	path: str,
};
