# macOS app manifest model port

`src/runtime/macos_app_manifest_model.elisa` ports the pure settings logic from
`../elisa-engine/scripts/package_macos_app.py`: the application title/name,
safe bundle name, default or explicit bundle identifier, output setting, and
window title/size. It consumes a sealed JSON document, requires Python's
last-value-wins duplicate-key behavior, and owns the returned text bytes so
settings do not borrow storage from the JSON document.

The same model now captures `package.resources` selection (`None`/`null` means
stage all assets, while an empty array means stage none) and normalizes
resource/notice paths with POSIX `pathlib.Path`-style separator and dot
handling. Resource paths reject absolute paths, parent components, and the
packager's ignored metadata names; duplicate resource paths retain their first
normalized occurrence. Notice syntax rejects absolute/parent/NUL and duplicate
paths. `src/runtime/macos_app_manifest_file_posix.elisa` now reads a bounded
UTF-8 `elisa.project.json`, uses Python-compatible last-key-wins JSON object
handling, and returns owned decoded settings plus resource/notice selections;
a temp-project fixture covers absent-manifest defaults and duplicate keys.
The loader currently caps input at 16 MiB, unlike Python's unbounded
`read_text()` path; raise or formally qualify that limit before claiming full
input-domain parity. It remains uncompiled and unrun.
`src/runtime/macos_app_filesystem_posix.elisa` implements the notice
filesystem predicate: canonical containment (including symlinked parent
directories escaping the project), symlink-leaf rejection, regular file kind,
and nonzero size. The containment check interprets `Path.relative_to` as a
lexical relative path and rejects a leading `..` component; that operation by
itself does not enforce ancestry. A regression fixture covers an in-project
notice reached through a directory symlink to a similarly prefixed sibling.
It also ports the selected-resource root
admission from the packaging workflow: implicit all-assets mode requires the
project's `assets/` directory, while explicitly selected paths must exist,
must not themselves be symlinks, and must be regular files or directories.
The filesystem module now stages selected resources and notices. Directory
traversal uses the per-entry ignore policy; notice destinations reject
pre-existing entries while ordinary file resources overwrite like `copy2`.
A new pure path-planning model compares absolute resolved paths by components,
not textual prefix, and treats unresolved relative operands as overlapping
(fail-closed). Its primitive fixtures cover equality, ancestor/descendant,
common-prefix siblings, and relative operands. It is not yet wired into app
publication; output canonicalization and the complete output-versus-input
matrix remain open. All new fixtures remain uncompiled and unrun.
A file-level Darwin adapter in
`src/runtime/macos_app_copy_posix.elisa` now calls `copyfile(3)` with data,
POSIX-stat, and xattr flags while following source symlinks; a focused fixture
is authored but unrun. Recursive resource staging now composes that adapter
with Elisa directory traversal and the asset-ignore policy, dereferences
symlinked descendants, rejects active directory cycles, and restores copied
directory modes. The pure policy in
`src/runtime/macos_app_asset_filter_model.elisa` now ports both the regular
asset litter exclusions and the additional shader metadata exclusions; its
fixture is authored but unrun. Directory timestamps/xattrs and Python's
best-effort xattr error behavior still need parity treatment. The app-package
entrypoint and transactional publication remain unported.

This is a component of a future `package_macos_app.elisascript`, not a package
replacement. The output remains a raw path setting; `expanduser()`, resolution
against the project, linked-library closure,
`otool`/`install_name_tool`/`codesign`, plist writing, and transactional bundle
publication are still unported. Python's non-standard
`NaN`/`Infinity` JSON acceptance is also not represented by the
standards-conforming JSON front end. The authored model fixture has not been
compiled or run under the explicit execution hold.
