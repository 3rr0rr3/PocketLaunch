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
ids = [str(uuid.uuid4()) for _ in range(3)]
games = [
    {"id": ids[0], "name": "South Park", "launchURL": "sidestore-org.nxnative.010095300b6a4000.5V7XAX44YG://", "favorite": True},
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
