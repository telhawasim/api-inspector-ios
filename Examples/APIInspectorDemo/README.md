
# APIInspectorDemo

1. Open `APIInspectorDemo.xcodeproj` in Xcode 16 or later.
2. Select an iOS 17 or newer simulator.
3. Run the `APIInspectorDemo` scheme.

The project links the repository through a local Swift package reference. The
demo manually records one sanitized transaction; automatic `URLSession`
capture belongs to Phase 2.

For command-line verification:

```sh
xcodebuild \
  -project Examples/APIInspectorDemo/APIInspectorDemo.xcodeproj \
  -scheme APIInspectorDemo \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```
