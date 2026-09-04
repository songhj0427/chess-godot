extends Node2D

const BOARD_SIZE := 8
const SQUARE_SIZE := 80
const BOARD_OFFSET := Vector2(80, 80)

const COLOR_LIGHT := Color("f0d9b5")
const COLOR_DARK := Color("b58863")
const COLOR_SELECT := Color(0.4, 0.8, 0.4, 0.5)

@onready var board_visual: Node2D = $BoardVisual
@onready var highlight_visual: Node2D = $HighlightVisual

var selected: Vector2i = Vector2i(-1, -1)

func board_to_screen(pos: Vector2i) -> Vector2:
	return BOARD_OFFSET + Vector2(pos) * SQUARE_SIZE

func screen_to_board(screen_pos: Vector2) -> Vector2i:
	var local := screen_pos - BOARD_OFFSET
	return Vector2i(floori(local.x / SQUARE_SIZE), floori(local.y / SQUARE_SIZE))

func is_inside(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < BOARD_SIZE and pos.y >= 0 and pos.y < BOARD_SIZE
	
func to_algebraic(pos: Vector2i) -> String:
	var file := char("a".unicode_at(0) + pos.x)
	var rank := 8 - pos.y
	return file + str(rank)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_create_board()
	
func _create_board() -> void:
	for row in BOARD_SIZE:
		for col in BOARD_SIZE:
			var square := ColorRect.new()
			square.size = Vector2(SQUARE_SIZE, SQUARE_SIZE)
			square.position = board_to_screen(Vector2i(col, row))
			square.color = COLOR_LIGHT if (row  + col) % 2 == 0 else COLOR_DARK
			square.mouse_filter = Control.MOUSE_FILTER_IGNORE
			board_visual.add_child(square)
			
func _unhandled_input(event: InputEvent) -> void:
	if event is not InputEventMouseButton:
		return
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
		
	var cell := screen_to_board(event.position)
	if is_inside(cell):
		_on_cell_clicked(cell)
		
func _on_cell_clicked(cell: Vector2i) -> void:
	selected = cell
	_update_highlight()
	print(cell, " = ", to_algebraic(cell))

func _update_highlight() -> void:
	for child in highlight_visual.get_children():
		child.queue_free()
		
	if not is_inside(selected):
		return
		
	var rect := ColorRect.new()
	rect.size = Vector2(SQUARE_SIZE, SQUARE_SIZE)
	rect.position = board_to_screen(selected)
	rect.color = COLOR_SELECT
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	highlight_visual.add_child(rect)
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
