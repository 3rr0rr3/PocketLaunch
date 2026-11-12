import pathlib, plistlib, struct
app = pathlib.Path("build/Build/Products/Release-iphoneos/PocketLaunch.app")
info = plistlib.loads((app / "Info.plist").read_bytes())
assert info["CFBundleDisplayName"] == "Iphone Switch"
assert info["CFBundleIdentifier"] == "com.personal.pocketlaunch"
assert info["CFBundleIcons"]["CFBundlePrimaryIcon"]["CFBundleIconName"] == "AppIcon"
assert (app / "Assets.car").is_file()
assert list(app.glob("AppIcon*.png")), "Missing compiled app icon"
png = pathlib.Path("Sources/Assets.xcassets/AppIcon.appiconset/AppIcon.png").read_bytes()
assert png[:8] == b"\x89PNG\r\n\x1a\n"
assert struct.unpack(">II", png[16:24]) == (1024, 1024)
assert png[25] == 2, "Icon must be opaque RGB"
print("Verified app name, unchanged bundle identifier, and compiled app icon")

assert (app / "PressStart2P-Regular.ttf").stat().st_size > 10000, "Missing arcade font"
assert (app / "OFL.txt").is_file(), "Missing font license"
