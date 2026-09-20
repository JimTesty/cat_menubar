# App icon

The app keeps the original artwork in `Resources/AppIcon.png` and packages a
native macOS icon in `Resources/AppIcon.icns`. The build script declares the
`.icns` file through `CFBundleIconFile`; it does not use the PNG directly.

Using the raw PNG as the bundle icon produced a black matte around the
transparent corners in Finder. A native `.icns` container preserves the alpha
channel correctly and gives macOS resolution-specific representations.

## Regenerate the icon

When the source artwork changes, run this from the repository root:

```bash
./make-app-icon.sh
```

The helper uses only tools already present on macOS:

1. `sips` creates 128×128, 256×256, and 512×512 RGBA PNGs from the source.
2. A small built-in Perl step wraps those PNGs in an ICNS header and resources:
   `ic07` for 128×128, `ic08` for 256×256, and `ic09` for 512×512.
3. `file` confirms that the result is recognized as a Mac OS X icon.

This compact three-representation icon is about 345 KB. Finder’s custom-folder
icon normally contains ten entries, including duplicate 1×/2× images and a
1024×1024 image; copying that resource wholesale made the bundle about 1.4 MB
without improving this app’s appearance.

## Verify the result

```bash
file Resources/AppIcon.icns
icon_tmp="$(mktemp -d /tmp/cat-menubar-icon-check.XXXXXX)"
iconutil -c iconset -o "$icon_tmp/AppIcon.iconset" Resources/AppIcon.icns
find "$icon_tmp/AppIcon.iconset" -maxdepth 1 -type f -print | sort
```

The extracted iconset should contain the 128×128, 256×256, and 512×512 PNGs.
Then rebuild the app:

```bash
./build-app.sh
```

## Finder custom-icon detail

When an icon is pasted onto a folder in Finder, macOS creates a zero-byte
`Icon` file whose name ends with a carriage return (`Icon\r`). The actual icon
is stored in that file’s `com.apple.ResourceFork` extended attribute, not in
the visible file contents. That resource fork can be inspected with:

```bash
icon_marker=$'Icon\r'
xattr -l "$icon_marker"
```

It is Finder metadata, not a source asset to commit. The repository ignores
such markers with the `Icon?` pattern.
