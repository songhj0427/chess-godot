class_name ChessBoard
extends RefCounted

const SIZE := 8

const BACK_RANK := [
	Piece.Type.ROOK, Piece.Type.KNIGHT, Piece.Type.BISHOP, Piece.Type.QUEEN,
	Piece.Type.KING, Piece.Type.BISHOP, Piece.Type.KNIGHT, Piece.Type.ROOK,
]

var board: Array = []

var turn: Piece.Side = Piece.Side.WHITE
var move_count: int = 0

func switch_turn() -> void:
	turn = Piece.Side.BLACK if turn == Piece.Side.WHITE else Piece.Side.WHITE
	move_count += 1

func _init() -> void:
	setup_initial()

func clear() -> void:
	board = []
	for row in SIZE:
		var line: Array = []
		line.resize(SIZE)
		board.append(line)

func setup_initial() -> void:
	clear()
	turn = Piece.Side.WHITE
	move_count = 0
	for col in SIZE:
		set_piece(Vector2i(col, 0), Piece.new(BACK_RANK[col], Piece.Side.BLACK))
		set_piece(Vector2i(col, 1), Piece.new(Piece.Type.PAWN, Piece.Side.BLACK))
		set_piece(Vector2i(col, 6), Piece.new(Piece.Type.PAWN, Piece.Side.WHITE))
		set_piece(Vector2i(col, 7), Piece.new(BACK_RANK[col], Piece.Side.WHITE))

func get_piece(pos: Vector2i) -> Piece:
	if not is_inside(pos):
		return null
	return board[pos.y][pos.x]

func set_piece(pos: Vector2i, piece: Piece) -> void:
	if not is_inside(pos):
		return
	board[pos.y][pos.x] = piece

func is_inside(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < SIZE and pos.y >= 0 and pos.y < SIZE

func is_empty(pos: Vector2i) -> bool:
	return get_piece(pos) == null

func move_piece(from: Vector2i, to: Vector2i) -> void:
	var piece := get_piece(from)
	if piece == null:
		return
	
	set_piece(to, piece)
	set_piece(from, null)
	piece.has_moved = true
