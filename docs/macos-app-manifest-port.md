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
paths. `src/runtime/macos_app_filesystem_posix.elisa` implements the notice
filesystem predicate: canonical containment, symlink-leaf rejection, regular
file kind, and nonzero size. It does not stage or copy notices; its
temp-directory fixture is authored but unrun.

This is a component of a future `package_macos_app.elisascript`, not a package
replacement. The output remains a raw path setting; `expanduser()`, resolution
against the project, resource filesystem staging, linked-library closure,
`otool`/`install_name_tool`/`codesign`, plist writing, and transactional bundle
publication are still unported. Python's non-standard
`NaN`/`Infinity` JSON acceptance is also not represented by the
standards-conforming JSON front end. The authored model fixture has not been
compiled or run under the explicit execution hold.
