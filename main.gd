extends Node2D

const BOARD_SIZE := 8
const SQUARE_SIZE := 80
const BOARD_OFFSET := Vector2(80, 80)

const COLOR_LIGHT := Color("f0d9b5")
const COLOR_DARK := Color("b58863")
const COLOR_SELECT := Color(0.4, 0.8, 0.4, 0.5)

@onready var board_visual: Node2D = $BoardVisual
@onready var highlight_visual: Node2D = $HighlightVisual
@onready var piece_visual: Node2D = $PieceVisual

var chess_board := ChessBoard.new()

var selected: Vector2i = Vector2i(-1, -1)

const SHEET_PATH := "res://assets/pieces.svg"
const SHEET_COLS := 6
const SHEET_ROWS := 2

const TYPE_NAMES := {
	Piece.Type.PAWN: "pawn",
	Piece.Type.KNIGHT: "knight",
	Piece.Type.BISHOP: "bishop",
	Piece.Type.ROOK: "rook",
	Piece.Type.QUEEN: "queen",
	Piece.Type.KING: "king",
}

const SIDE_NAMES := {
	Piece.Side.WHITE: "white",
	Piece.Side.BLACK: "black",
}

const SHEET_ORDER := [
	Piece.Type.KING, Piece.Type.QUEEN, Piece.Type.BISHOP,
	Piece.Type.KNIGHT, Piece.Type.ROOK, Piece.Type.PAWN,
]

const SHEET_SIDE_ROW := {
	Piece.Side.WHITE: 0,
	Piece.Side.BLACK: 1,
}

var textures: Dictionary = {}

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
	_load_textures()
	_create_board()
	_update_pieces()
	
func _update_pieces() -> void:
	for child in piece_visual.get_children():
		child.queue_free()
	
	for row in ChessBoard.SIZE:
		for col in ChessBoard.SIZE:
			var pos := Vector2i(col, row)
			var piece := chess_board.get_piece(pos)
			if piece == null:
				continue
			_spawn_piece_sprite(piece, pos)

func _spawn_piece_sprite(piece: Piece, pos: Vector2i) -> void:
	var key: String = "%s_%s" % [SIDE_NAMES[piece.side], TYPE_NAMES[piece.type]]
	var sprite := Sprite2D.new()
	sprite.texture = textures[key]
	sprite.position = board_to_screen(pos) + Vector2.ONE * SQUARE_SIZE * 0.5
	
	var tex_size := sprite.texture.get_size()
	var fit := SQUARE_SIZE * 0.85 / maxf(tex_size.x, tex_size.y)
	sprite.scale = Vector2.ONE * fit
	
	piece_visual.add_child(sprite)
	
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
	
	var piece := chess_board.get_piece(cell)
	if piece == null:
		print(to_algebraic(cell), " : 빈 칸")
	else:
		print(to_algebraic(cell), " : ", SIDE_NAMES[piece.side], " ", TYPE_NAMES[piece.type])

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
	
func _load_textures() -> void:
	var sheet: Texture2D = load(SHEET_PATH)
	var cell := Vector2(
		sheet.get_width() / float(SHEET_COLS),
		sheet.get_height() / float(SHEET_ROWS)
	)
	
	for side in SHEET_SIDE_ROW:
		for col in SHEET_ORDER.size():
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(
				Vector2(col, SHEET_SIDE_ROW[side]) * cell,
				cell
			)
			
			var key: String = "%s_%s" % [SIDE_NAMES[side], TYPE_NAMES[SHEET_ORDER[col]]]
			textures[key] = atlas

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
