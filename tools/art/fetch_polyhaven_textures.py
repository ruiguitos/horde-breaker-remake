"""Downloads the Poly Haven (CC0) maps used by the zombie and weapon art.

Usage: python -I tools/art/fetch_polyhaven_textures.py <download_dir>
Then pack them into assets/textures/polyhaven/ with
  godot --headless --path . --script res://tools/art/pack_textures.gd -- <download_dir>
Only the Poly Haven API is contacted. Raw downloads stay outside the repo.
"""
import json
import os
import sys
import urllib.request

# id -> resolution stored in the repo (packer reads the same table).
TEXTURES = {
    # Zombies (small on screen: 512 px is plenty).
    "leather_white": "1k",      # skin base (tinted, rot blotches on top)
    "cotton_jersey": "1k",      # T-shirts
    "denim_fabric_06": "1k",    # jeans
    "fabric_leather_02": "1k",  # jackets, belts, boots
    "rough_linen": "1k",        # work shirts, trousers
    # Weapons (seen up close in first person).
    "blue_metal_plate": "1k",   # gunmetal (tinted dark, metallic)
    "rubberized_track": "1k",   # polymer grips and furniture
    "american_walnut_veneer": "1k",  # wooden stocks
}
MAPS = [("Diffuse", "diffuse"), ("nor_gl", "nor_gl"), ("Rough", "rough")]


def get(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": "horde-breaker-remake asset fetch"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read()


def main() -> None:
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    for asset, res in TEXTURES.items():
        files = json.loads(get("https://api.polyhaven.com/files/" + asset))
        for kind, name in MAPS:
            path = os.path.join(out, "%s_%s.jpg" % (asset, name))
            if os.path.exists(path):
                continue
            url = files[kind][res]["jpg"]["url"]
            if not url.startswith("https://dl.polyhaven.org/"):
                raise SystemExit("unexpected host: " + url)
            with open(path, "wb") as f:
                f.write(get(url))
            print("  " + path)
    print("Done: " + out)


if __name__ == "__main__":
    main()
