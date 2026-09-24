The APP plist path is a directory rather than a regular file. The process
comparison requires status 1, empty stdout, and both implementations to include
the APP plist basename in their read-failure diagnostics. This preserves the
CMake `EXISTS`-then-`file(READ)` behavior without depending on platform-specific
error wording.
