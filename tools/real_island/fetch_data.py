"""Downloads the real-world data for the real_island spike into data/.

    python tools/real_island/fetch_data.py [place]

Places are presets below (default: berlenga). Downloads, once:
  - elevation tiles (AWS Terrain Tiles, "terrarium" PNG, zoom 15, about 3.7 m
    per pixel here; the source data is coarser, about 25-30 m);
  - OpenStreetMap features (Overpass API): coastline, paths, steps, bridges,
    buildings, lighthouse, pier, beaches;
  - four CC0 ground textures from Poly Haven (1k: colour, normal, roughness,
    displacement).
data/ is ignored by git: only the island built from it (build.gd) is kept.
OSM data is ODbL: "(c) OpenStreetMap contributors" (see assets/LICENSES.md).
Only the Python standard library is used.
"""

import json
import math
import os
import sys
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, "data")
AGENT = "horde-breaker-remake real_island spike (Godot test project)"

# centre (lat, lon) and side of the square map in metres.
PLACES = {
    "berlenga": {"name": "Berlenga Grande", "lat": 39.4143, "lon": -9.5096, "size": 2048},
}
ZOOM = 15
TEXTURES = {  # Poly Haven asset -> role on the terrain
    "aerial_grass_rock": "ground",
    "rock_face_03": "cliff",
    "coast_sand_rocks_02": "shore",
    "rocky_trail": "path",
}


def get(url: str, data: bytes = None) -> bytes:
    req = urllib.request.Request(url, data=data, headers={"User-Agent": AGENT})
    with urllib.request.urlopen(req, timeout=120) as r:
        return r.read()


def save(path: str, blob: bytes) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(blob)
    print("  %s (%d KB)" % (os.path.relpath(path, HERE), len(blob) // 1024))


def tile_xy(lat: float, lon: float) -> tuple:
    n = 2 ** ZOOM
    x = (lon + 180.0) / 360.0 * n
    y = (1.0 - math.asinh(math.tan(math.radians(lat))) / math.pi) / 2.0 * n
    return x, y


def main() -> None:
    key = sys.argv[1] if len(sys.argv) > 1 else "berlenga"
    place = PLACES[key]
    half = place["size"] / 2.0
    dlat = half / 110574.0
    dlon = half / (111320.0 * math.cos(math.radians(place["lat"])))
    south, north = place["lat"] - dlat, place["lat"] + dlat
    west, east = place["lon"] - dlon, place["lon"] + dlon

    print("Elevation tiles (AWS Terrain Tiles, terrarium):")
    x0, y0 = tile_xy(north, west)
    x1, y1 = tile_xy(south, east)
    tiles = []
    for ty in range(int(y0), int(y1) + 1):
        for tx in range(int(x0), int(x1) + 1):
            path = os.path.join(DATA, "dem", "%d_%d_%d.png" % (ZOOM, tx, ty))
            if not os.path.exists(path):
                save(path, get("https://s3.amazonaws.com/elevation-tiles-prod/terrarium/%d/%d/%d.png" % (ZOOM, tx, ty)))
            tiles.append([ZOOM, tx, ty])

    print("OpenStreetMap (Overpass API):")
    osm_path = os.path.join(DATA, "osm.json")
    if not os.path.exists(osm_path):
        bbox = "%f,%f,%f,%f" % (south, west, north, east)
        query = "[out:json][timeout:90];(" + "".join(
            '%s%s(%s);' % (kind, flt, bbox) for kind, flt in [
                ("way", '["natural"="coastline"]'), ("way", '["highway"]'), ("way", '["building"]'),
                ("way", '["man_made"]'), ("node", '["man_made"="lighthouse"]'), ("way", '["natural"="beach"]'),
                ("way", '["landuse"]'), ("way", '["historic"]'),
            ]) + ");out body geom;"
        save(osm_path, get("https://overpass-api.de/api/interpreter", urllib.parse.urlencode({"data": query}).encode()))

    print("Ground textures (Poly Haven, CC0):")
    for asset in TEXTURES:
        files = json.loads(get("https://api.polyhaven.com/files/" + asset))
        for kind, fmt in [("Diffuse", "jpg"), ("nor_gl", "jpg"), ("Rough", "jpg"), ("Displacement", "png")]:
            path = os.path.join(DATA, "textures", "%s_%s.%s" % (asset, kind.lower(), fmt))
            if not os.path.exists(path):
                save(path, get(files[kind]["1k"][fmt]["url"]))

    meta = dict(place, key=key, zoom=ZOOM, tiles=tiles, bbox=[south, west, north, east], textures=TEXTURES)
    with open(os.path.join(DATA, "meta.json"), "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=1)
    with open(os.path.join(DATA, ".gdignore"), "w") as f:
        f.write("")  # Godot does not import the raw downloads; the builder reads them directly
    print("Done: %s" % DATA)


if __name__ == "__main__":
    main()
