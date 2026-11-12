"""Verify existing library cards receive automatic artwork on an iPhone simulator."""
import base64
import json
import pathlib
import subprocess
import time
import uuid

BUNDLE = "com.personal.pocketlaunch"

def run(*args):
    return subprocess.check_output(args, text=True).strip()

devices = json.loads(run("xcrun", "simctl", "list", "devices", "available", "-j"))["devices"]
phone = next(device for group in devices.values() for device in group if device["name"].startswith("iPhone"))
device = phone["udid"]
if phone["state"] != "Booted":
    subprocess.run(["xcrun", "simctl", "boot", device], check=True)
subprocess.run(["xcrun", "simctl", "bootstatus", device, "-b"], check=True)
subprocess.run([
    "xcodebuild", "-project", "PocketLaunch.xcodeproj", "-scheme", "PocketLaunch",
    "-configuration", "Debug", "-sdk", "iphonesimulator",
    "-destination", "id=" + device, "-derivedDataPath", "simulator-build",
    "CODE_SIGNING_ALLOWED=NO", "build"
], check=True)
app = "simulator-build/Build/Products/Debug-iphonesimulator/PocketLaunch.app"
subprocess.run(["xcrun", "simctl", "install", device, app], check=True)
container = pathlib.Path(run("xcrun", "simctl", "get_app_container", device, BUNDLE, "data"))
documents = container / "Documents"
documents.mkdir(parents=True, exist_ok=True)
saved = documents / "games.json"
custom = base64.b64encode(b"existing-custom-artwork-must-not-be-overwritten").decode()
ids = [str(uuid.uuid4()).upper() for _ in range(3)]
games = [
    {"id": ids[0], "name": "Animal Crossings New Horizon", "launchURL": "sidestore-org.nxnative.010095300b6a4000.5V7XAX44YG://", "favorite": True},
    {"id": ids[1], "name": "Custom cover", "launchURL": "org.nxnative.010095300b6a4000://", "favorite": False, "artwork": custom},
    {"id": ids[2], "name": "Unknown game", "launchURL": "unknown-game://", "favorite": False},
]
saved.write_text(json.dumps(games))
subprocess.run(["xcrun", "simctl", "launch", device, BUNDLE], check=True)
for attempt in range(45):
    current = json.loads(saved.read_text())
    by_id = {game["id"]: game for game in current}
    if by_id[ids[0]].get("artwork"):
        break
    time.sleep(1)
else:
    raise AssertionError("South Park artwork was not filled automatically within 45 seconds")
assert len(base64.b64decode(by_id[ids[0]]["artwork"])) > 1024
assert by_id[ids[0]]["favorite"] is True
assert by_id[ids[1]]["artwork"] == custom
assert not by_id[ids[2]].get("artwork")
subprocess.run(["xcrun", "simctl", "io", device, "screenshot", "automatic-artwork-preview.png"], check=True)
print("PASS: existing South Park card filled automatically; custom artwork and favorites preserved.")

# Review utility text separately from the arcade home headings.
subprocess.run(["xcrun", "simctl", "launch", "--terminate-running-process", device, BUNDLE, "--preview-ipa-library"], check=True)
time.sleep(3)
subprocess.run(["xcrun", "simctl", "io", device, "screenshot", "ipa-library-preview.png"], check=True)

# Capture the real native animation. This preview route exists only in Debug builds.
import signal
recording = subprocess.Popen(
    ["xcrun", "simctl", "io", device, "recordVideo", "--codec=h264", "clean-cartridge-animation.mp4"],
    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
)
try:
    time.sleep(1)
    subprocess.run(["xcrun", "simctl", "launch", "--terminate-running-process", device, BUNDLE, "--preview-cartridge"], check=True)
    time.sleep(0.3)
    subprocess.run(["xcrun", "simctl", "io", device, "screenshot", "clean-cartridge-start.png"], check=True)
    time.sleep(6)
    subprocess.run(["xcrun", "simctl", "io", device, "screenshot", "clean-cartridge-finish.png"], check=True)
finally:
    recording.send_signal(signal.SIGINT)
    recording.wait(timeout=30)
assert pathlib.Path("clean-cartridge-animation.mp4").stat().st_size > 1000
print("Captured clean cartridge animation with the selected game's artwork.")
