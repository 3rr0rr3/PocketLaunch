"""Build a compact title-ID-to-icon index; no game files are included."""
import json
import pathlib
import re
import time
import urllib.request
from urllib.parse import urlsplit

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "Resources" / "AutomaticArtwork"
DATABASE = "https://raw.githubusercontent.com/blawar/titledb/master/US.en.json"
LICENSE = "https://raw.githubusercontent.com/blawar/titledb/master/LICENSE"
SOUTH_PARK = "010095300B6A4000"

def download(url):
    for attempt in range(3):
        try:
            with urllib.request.urlopen(url, timeout=90) as response:
                return response.read()
        except Exception:
            if attempt == 2:
                raise
            time.sleep(2)

def make_index(records):
    index = {}
    for record in records.values():
        if not isinstance(record, dict) or record.get("isDemo"):
            continue
        title = str(record.get("id") or "").upper()
        icon = record.get("iconUrl")
        if not re.fullmatch(r"[0-9A-F]{16}", title) or not isinstance(icon, str):
            continue
        url = urlsplit(icon)
        if url.scheme != "https" or url.netloc != "img-eshop.cdn.nintendo.net":
            continue
        index.setdefault(title, icon)
    return index

if __name__ == "__main__":
    index = make_index(json.loads(download(DATABASE)))
    assert SOUTH_PARK in index, "South Park title ID is missing from the artwork index"
    OUTPUT.mkdir(parents=True, exist_ok=True)
    (OUTPUT / "artwork-index.json").write_text(json.dumps(index, separators=(",", ":")), encoding="utf-8")
    (OUTPUT / "TitleDB-LICENSE.txt").write_bytes(download(LICENSE))
    # Seed the user's known South Park icon so that it works without a network request on the phone.
    image = download(index[SOUTH_PARK])
    assert image.startswith(b"\xff\xd8"), "Expected a JPEG game icon"
    (OUTPUT / (SOUTH_PARK + ".jpg")).write_bytes(image)
    print(f"Indexed {len(index)} exact game IDs; bundled South Park's game icon.")
