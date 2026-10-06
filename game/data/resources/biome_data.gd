class_name BiomeData
extends Resource
## Look and feel of an island biome (game/data/biomes/).

@export var display_name: String = ""
@export var coast: Color = Color.WHITE
@export var inland: Color = Color.WHITE
@export var building: Color = Color.WHITE
@export var foliage: Color = Color.WHITE
@export var sky: Color = Color.WHITE
@export var fog: float = 0.0
@export var palms: bool = false
@export var on_route: bool = true  ## offered on the boat (the volcano is always the last island)
@export var order: int = 0
## Colour grading of the biome (Color Grading addon: create a ColorGrading
## here and tune it with the colour wheels in the inspector). Empty = none.
@export var grading: CompositorEffect
