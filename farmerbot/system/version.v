module system

pub const (
	version_major = u8(0)
	version_minor = u8(2)
	version_patch = u8(0)
	extension     = '-rc9'

	version       = '${version_major}.${version_minor}.${version_patch}${extension}'
)
