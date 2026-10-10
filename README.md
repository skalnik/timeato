# Timeato

A pomodoro timer for macOS that I don't hate.

## Build

You need Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
xcodegen generate
xcodebuild -scheme Timeato -configuration Release build
```

You can also open `Timeato.xcodeproj` in Xcode.

The script `scripts/build.sh` does these steps. It puts the output in
`build/DerivedData` and prints the path of the app:

```sh
scripts/build.sh
```

## Test

```sh
xcodebuild test -scheme Timeato -destination 'platform=macOS' \
  -derivedDataPath build/DerivedData
```

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
