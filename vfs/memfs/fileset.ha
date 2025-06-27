//! Partitions a list of files into disjoint subsets.
//!
//! Files which do not belong to any explicitly configured `FileSet` belong to
//! the default `FileSet`.

// A set of [[vfspath]]s identified by [[fileid]]s
// export type fileset = struct {
// 	files: vfspath_fileid_map,
// 	paths: fileid_vfspath_map,
// };
def v: void = void;
