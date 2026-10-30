# App branding

`TUMicon.png` at the repository root is the original supplied bamboo logo.
`tum-logo-master.png` is its transparent cutout, made with the built-in imagegen
tool. It is the source for all app exports; it is not bundled into the Flutter app.

Regenerate the PNG exports with Python 3 and ImageMagick 7:

```sh
python3 scripts/generate_branding.py
```

The exports cover:

- Transparent Flutter logo at 1x, 2x, 3x, and 4x, used in both themes.
- Android legacy square/round icons and adaptive foreground, cream background,
  and monochrome layers at mdpi through xxxhdpi.
- Every existing iPhone, iPad, macOS, and App Store icon slot in both the app
  and CalendarWidget asset catalogs. These icons have opaque backgrounds.
- iOS launch logo at 1x, 2x, and 3x, and Android launch-logo densities.

The adaptive foreground fits inside Android's
[66dp safe area](https://developer.android.com/develop/ui/compose/system/icon_design_adaptive).
The export script derives Apple icon dimensions from each catalog's
`Contents.json`. PNG preserves the watercolor details and alpha; the artwork
is raster, so no synthetic SVG tracing is used.

## Cutout prompt

Use case: background-extraction. Edit the supplied TUMicon.png image into a
production logo cutout. Remove ONLY the off-white textured paper background,
including all empty spaces between and inside the bamboo T U M letters and
around the leaves, replacing it with genuine transparent alpha. Preserve the
exact existing bamboo TUM lettering, silhouette, proportions, green and yellow
watercolor coloring, dark outlines, leaf shapes and placement, fine painted
texture and highlights. Do not redraw, reinterpret, recolor, add shadows, add a
border, add text, or change the design. All three letters and every leaf must
remain complete and uncropped. Center the original artwork on a transparent
canvas with a small clear margin. This is the master logo for a mobile app.
