"""Downloads the real-world data of one place into data/<place>/.

    python tools/real_island/fetch_data.py [place]

Places are presets below (default: berlenga). Downloads, once:
  - elevation tiles (AWS Terrain Tiles, "terrarium" PNG, zoom 15, about 3.7 m
    per pixel; the source data is coarser, about 25-30 m);
  - OpenStreetMap features (Overpass API): coastline, paths, steps, bridges,
    buildings, walls, landmarks, land use;
  - the place's CC0 textures from Poly Haven (1k: colour, normal, roughness,
    displacement), each with a role: ground, cliff, shore and path for the
    terrain, facade for building walls.
data/ is ignored by git: only the island built from it (build.gd) is kept.
OSM data is ODbL: "(c) OpenStreetMap contributors" (see assets/LICENSES.md).
Only the Python standard library is used.
"""

import json
import math
import os
import sys
import time
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
AGENT = "horde-breaker-remake real_island tool (Godot test project)"
ZOOM = 15

# centre (lat, lon), side of the square downloaded in metres, and the Poly
# Haven textures with their role.
PLACES = {
    "berlenga": {
        "name": "Berlenga Grande", "lat": 39.4143, "lon": -9.5096, "size": 2048,
        "textures": {"aerial_grass_rock": "ground", "rock_face_03": "cliff",
                     "coast_sand_rocks_02": "shore", "rocky_trail": "path"},
    },
    "hashima": {
        "name": "Hashima (Gunkanjima)", "lat": 32.6278, "lon": 129.7386, "size": 1024,
        "textures": {"cracked_concrete": "ground", "concrete_wall_006": "cliff",
                     "dark_rock": "shore", "concrete_pavement_03": "path", "concrete_wall_008": "facade"},
    },
}
OVERPASS = ["https://overpass-api.de/api/interpreter", "https://overpass.private.coffee/api/interpreter",
            "https://overpass.kumi.systems/api/interpreter"]
MAPS = [("Diffuse", "diffuse"), ("nor_gl", "nor_gl"), ("Rough", "rough"), ("Displacement", "displacement")]


def get(url: str, data: bytes = None, tries: int = 4) -> bytes:
    for attempt in range(tries):  # servers have bad moments (502, 522...): wait and retry
        try:
            req = urllib.request.Request(url, data=data, headers={"User-Agent": AGENT})
            with urllib.request.urlopen(req, timeout=120) as r:
                return r.read()
        except OSError as e:
            if attempt == tries - 1:
                raise
            print("  retry in %d s (%s: %s)" % (15 * (attempt + 1), url, e))
            time.sleep(15 * (attempt + 1))


def save(path: str, blob: bytes, root: str) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(blob)
    print("  %s (%d KB)" % (os.path.relpath(path, root), len(blob) // 1024))


def tile_xy(lat: float, lon: float) -> tuple:
    n = 2 ** ZOOM
    x = (lon + 180.0) / 360.0 * n
    y = (1.0 - math.asinh(math.tan(math.radians(lat))) / math.pi) / 2.0 * n
    return x, y


def main() -> None:
    key = sys.argv[1] if len(sys.argv) > 1 else "berlenga"
    place = PLACES[key]
    data = os.path.join(HERE, "data", key)
    half = place["size"] / 2.0
    dlat = half / 110574.0
    dlon = half / (111320.0 * math.cos(math.radians(place["lat"])))
    south, north = place["lat"] - dlat, place["lat"] + dlat
    west, east = place["lon"] - dlon, place["lon"] + dlon

    print("Elevation tiles (AWS Terrain Tiles, terrarium):")
    x0, y0 = tile_xy(north, west)
    x1, y1 = tile_xy(south, east)
    for ty in range(int(y0), int(y1) + 1):
        for tx in range(int(x0), int(x1) + 1):
            path = os.path.join(data, "dem", "%d_%d_%d.png" % (ZOOM, tx, ty))
            if not os.path.exists(path):
                save(path, get("https://s3.amazonaws.com/elevation-tiles-prod/terrarium/%d/%d/%d.png" % (ZOOM, tx, ty)), data)

    print("OpenStreetMap (Overpass API):")
    osm_path = os.path.join(data, "osm.json")
    if not os.path.exists(osm_path):
        bbox = "%f,%f,%f,%f" % (south, west, north, east)
        query = "[out:json][timeout:90];(" + "".join(
            '%s%s(%s);' % (kind, flt, bbox) for kind, flt in [
                ("way", '["natural"]'), ("way", '["highway"]'), ("way", '["building"]'),
                ("way", '["man_made"]'), ("node", '["man_made"]'), ("way", '["landuse"]'),
                ("way", '["historic"]'), ("way", '["barrier"]'), ("node", '["name"]'),
                ("way", '["leisure"]'), ("way", '["amenity"]'),
            ]) + ");out body geom;"
        body = urllib.parse.urlencode({"data": query}).encode()
        for attempt, server in enumerate(OVERPASS * 2):  # busy servers answer 429/504: try the next
            try:
                save(osm_path, get(server, body), data)
                break
            except OSError as e:
                print("  %s: %s" % (server, e))
                if attempt == len(OVERPASS) * 2 - 1:
                    raise
                time.sleep(10)

    print("Textures (Poly Haven, CC0):")
    for asset in place["textures"]:
        files = json.loads(get("https://api.polyhaven.com/files/" + asset))
        for kind, name in MAPS:
            if kind not in files:
                continue  # not every texture has a displacement map
            fmt = "png" if kind == "Displacement" and "png" in files[kind]["1k"] else "jpg"
            path = os.path.join(data, "textures", "%s_%s.%s" % (asset, name, fmt))
            if not os.path.exists(path):
                save(path, get(files[kind]["1k"][fmt]["url"]), data)

    meta = dict(place, key=key, zoom=ZOOM, bbox=[south, west, north, east])
    with open(os.path.join(data, "meta.json"), "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=1)
    with open(os.path.join(HERE, "data", ".gdignore"), "w") as f:
        f.write("")  # Godot does not import the raw downloads; the builder reads them directly
    print("Done: %s" % data)


if __name__ == "__main__":
    main()
