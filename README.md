# Timeato

A pomodoro timer for macOS that I don't hate.

## Build

You need Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
make build
```

There are two app targets:

- `Timeato` is the direct download. It gets updates from Sparkle.
- `Timeato-AppStore` is the Mac App Store app. It does not contain
  Sparkle, because the App Store gives the updates. Build it with
  `make build-appstore`.

The two targets share the code in `Sources/Timeato`. The files that are
different for each target are in `Sources/Direct` and `Sources/AppStore`.

## Test

```sh
make test
```

## Release

1. `make bump`. This sets the version to the date (YYYY.MM.DD) and the
   build number to the time (YYYYMMDDHHMM) in `project.yml`.
2. `make release`. This archives and signs the app, adds the release
   to `appcast.xml`, commits the release, makes the GitHub release, and
   pushes `main`.

## License

The code is available under the MIT License. See [LICENSE](LICENSE).

The MIT License does not cover the three tomato icons. The icons have their
own license. See the credits below.

## Credits

The work icon is "Tomato" by Hana from the Noun Project,
https://thenounproject.com/icon/tomato-4597030/.

The break icon is a changed version of the same icon. It's got
sunglasses now. The app icon is also based upon it, but colorized.

All of these icons use the Creative Commons Attribution 3.0 license
(https://creativecommons.org/licenses/by/3.0/).

Updates of the direct download use [Sparkle](https://github.com/sparkle-project/Sparkle). Sparkle
uses the MIT License
(https://github.com/sparkle-project/Sparkle/blob/2.x/LICENSE).
