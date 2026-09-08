# Tennis Tracker App Icon

Created with the built-in image-generation tool for build 27. The mark is a deep
forest tennis ball with bold TT lettering on electric tennis yellow. The square,
opaque RGB artwork is intentionally unmasked so iOS and watchOS apply their own
rounded-square and circular masks. The app's accessible Home Screen name remains
Tennis Tracker; the graphic contains no essential instructions.

The source artwork is `TennisTrackerIcon-source.png`. Both targets use the same
1024-pixel RGB PNG in their `Assets.xcassets/AppIcon.appiconset`. These use Apple's
supported single-size asset-catalog workflow, not the separate 1088-pixel watchOS
Icon Composer canvas. Xcode produces the platform-specific icon renditions.

The generation source is exported to 1024 pixels with Lanczos resampling and RGB
pixel format. No rounded corners or circular mask are baked into the shipped PNG.
`Scripts/test_app_icons.py` checks dimensions, opaque format and matching artwork;
`Scripts/verify_app_icons.py` also checks both compiled bundles inside the IPA.
The native check uses Apple's assetutil to verify opaque sRGB AppIcon renditions
inside each Assets.car. watchOS stores its icon there without a loose PNG. The
catalogue SHA-256 is retained so the signed Windows package must contain the exact
catalogue inspected on the Mac builder.

## Apple Guidance

- [App icon design](https://developer.apple.com/design/human-interface-guidelines/app-icons?changes=__2_5&language=objc)
- [Single-size asset catalogues](https://developer.apple.com/documentation/xcode/configuring-your-app-icon?changes=_2)

## Generation Prompt

Use case: logo-brand. Create a finished app icon artwork for Tennis Tracker on
iPhone and Apple Watch, a professional accessible tennis activity tracker. Single
square 1024 by 1024 PNG, fully opaque, sRGB, artwork fills all four edges; no rounded
corners, no applied circular mask, no device mockup, no inset icon tile. Flat
electric tennis-ball yellow/lime background (#D8F51C), extremely bright and bold.
In the center a distinctive large, clean near-black deep forest-green tennis-ball
emblem, with two beautiful thick curved tennis-ball seams and a compact custom
interlocking TT monogram integrated creatively into its middle. Emblem must
unmistakably read as tennis first, premium modern sports identity, confident
original geometric lettering, simple enough to recognize at 40 pixels. Monogram
exactly TT, no other words or microtext. All important dark artwork centered
within the middle 70 percent diameter to survive Apple Watch circular cropping;
generous bright margin surrounding the emblem. Graphic design, crisp clean
edges, perfectly balanced optical weight, high contrast dark forest against
fluorescent tennis yellow, not a photo, no fuzzy texture, no gradients, no
highlights, no shadow, no glass, no border, no watermark, no logos from existing
brands. Deliver only the finished square icon artwork.
