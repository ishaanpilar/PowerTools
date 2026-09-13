# Trademarks

The source code in this repository is licensed under GPL-3.0-or-later. That
license covers copyright in the source code only. It does not cover names,
logos, icons or other brand material — neither PowerTools' nor anyone else's.

## PowerTools brand material

The GPL license does not grant permission to use the PowerTools name, logo,
icon, bundle identity, trade dress, official branding, or any signing identity
controlled by the project maintainer.

Official PowerTools builds are distributed only by the project maintainer.
Unofficial forks and redistributed builds must use a different name, app icon,
bundle identifier, signing identity, update feed, and any other branding that
could imply endorsement or official status.

Do not present a modified build as PowerTools or as an official release unless
you have explicit permission from the project maintainer.

## Upstream brand material

PowerTools is a fork of [Vorssaint](https://github.com/vorssaint/vorssaint-utils),
used under GPL-3.0-or-later. The GPL grant covers that project's source code.
It does not cover the Vorssaint name, logo, icon, bundle identity or trade
dress, and Vorssaint's own trademark notice explicitly requires forks to adopt
a different name, app icon, bundle identifier, signing identity and update
feed.

PowerTools therefore uses its own name, its own bundle identifier
(`com.powertools.utils`), its own signing identity and its own update feed.
Nothing in this repository is an official Vorssaint build, and nothing here is
endorsed by or affiliated with the Vorssaint project.

No Vorssaint artwork remains in this repository. The PowerTools mark is an
original geometric design and carries none of upstream's trade dress.

## The PowerTools mark

The mark is three rounded modules — one tall, two stacked — on a near-black
squircle, in volt lime `#A3E635` with a single mint `#00E5A0` module.

Its geometry is defined once, in `Tools/MakeBrandAssets.swift`, which renders
every rendition from that one definition: the app icon master, the mono master
the menu bar template and in-app mark are cut from, the Icon Composer vector,
and the documentation logos. Change the mark there and re-run it; do not edit
the generated files by hand, or the renditions will drift apart.

```sh
swift Tools/MakeBrandAssets.swift
```

`PowerTools --selftest` reads the brand colour back out of the shipped app icon
and compares it with `Theme.brandLime`, so the app's own palette and its icon
cannot silently diverge.

The mark, the name, and the palette as applied to them are PowerTools brand
material. They are excluded from the GPL-3.0-or-later license covering the
source code, exactly as the first section of this document describes.
