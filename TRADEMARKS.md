# Trademarks

The source code in this repository is licensed under GPL-3.0-or-later. That
licence covers copyright in the source code only. It does not cover names,
logos, icons or other brand material.

## PowerTools AI brand material

The GPL does not grant permission to use the PowerTools AI name, mark, app
icon, bundle identity, trade dress, or any signing identity controlled by the
maintainer.

Official PowerTools AI builds are distributed only by the maintainer. Forks
and redistributed builds must use their own name, app icon, bundle identifier,
signing identity and update feed, and must not suggest they are official or
endorsed.

## The mark

The mark is three rounded modules — one tall, two stacked — on a near-black
squircle, in volt lime `#A3E635` with a single mint `#00E5A0` module.

Its geometry is defined once, in `Tools/MakeBrandAssets.swift`, which renders
every rendition from that definition: the app icon master, the mono master that
the menu bar template and in-app mark are cut from, the Icon Composer vector, and
the documentation logos. Change the mark there and re-run it; never edit the
generated files by hand.

```sh
swift Tools/MakeBrandAssets.swift
```

`PowerTools --selftest` reads the brand colour back out of the shipped app icon
and compares it with `Theme.brandLime`, so the palette and the icon cannot
silently diverge.

The name, the mark and the palette as applied to them are PowerTools AI brand
material, excluded from the GPL-3.0-or-later licence covering the source code.

## Other names

Apple, macOS, Apple Intelligence and other names mentioned in this repository
belong to their owners. Naming a project or company here, including in the
README's credits, does not imply affiliation or endorsement.
