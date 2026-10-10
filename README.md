# Timeato

A pomodoro timer for macOS that I don't hate.

## Build

You need Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
make build
```

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

The MIT License does not cover the two tomato icons. The icons have their
own license. See the credits below.

## Credits

The work icon is "Tomato" by Hana from the Noun Project,
https://thenounproject.com/icon/tomato-4597030/.

The break icon is a changed version of the same icon. It's got
sunglasses now.

Both icons use the Creative Commons Attribution 3.0 license
(https://creativecommons.org/licenses/by/3.0/).

Updates use [Sparkle](https://github.com/sparkle-project/Sparkle). Sparkle
uses the MIT License
(https://github.com/sparkle-project/Sparkle/blob/2.x/LICENSE).
