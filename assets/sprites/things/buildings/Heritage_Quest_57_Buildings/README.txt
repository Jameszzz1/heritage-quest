HERITAGE QUEST: 57 BUILDING EXTERIORS
8 each: city, modest homes, middle-income homes, upscale homes, subdivision,
farm, and food buildings; plus a modern wooden main-character home base.

Original Philippine-inspired designs using your existing building as camera
and style reference. These are not exact replicas of named properties.
Food-chain style outlets are unbranded fictional designs.

sprites/: 57 separate transparent PNGs, ready to import as textures.
high_resolution/: 57 larger cleaned cutouts for optional refinement.
atlases/: 4 columns by 2 rows, zero cell spacing. Cell sizes match sprites.
godot_scenes/: optional Godot 4 Sprite2D scenes; keep folder structure intact.
previews/ and CATALOG.png: labeled previews; not game textures.
manifest.json: paths, canvas sizes and bottom-center anchors.

Copy the whole folder under res://. Drag a scene into your level or assign
a PNG to a Sprite2D. Scenes use nearest texture filtering, with origin near
the lower center. Adjust scale to your character and map. Ground tiles remain
32x32; buildings span multiple tiles. Canvas sizes are not collision footprints.
Most sprites are 256x256, city 320x384, and home base 384x256. Avoid fractional
scaling for crisp edges.

Programmer setup: add ground-footprint collision, entrance interactions,
navigation and appropriate Y sorting. Porches are not automatically walkable.
No interiors, animations, collision or interaction code is included. Doors,
roofs, attached props and fire-station vehicles are baked into the artwork.
Review proportions and camera consistency in your actual game before release.

Validation: 57 sprites, hard alpha 0/255, transparent outer canvas borders,
and scene texture references checked. Background halos removed and buildings
isolated by connected components to avoid grid clipping. No Godot runtime
test was performed in your project.
