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

const DIR_STRAIGHT: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0),
]

const DIR_DIAGONAL: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1),
]

const DIR_ALL: Array[Vector2i] = DIR_STRAIGHT + DIR_DIAGONAL

const KNIGHT_OFFSETS: Array[Vector2i] = [
	Vector2i(1, -2), Vector2i(2, -1), Vector2i(2, 1), Vector2i(1, 2),
	Vector2i(-1, 2), Vector2i(-2, 1), Vector2i(-2, -1), Vector2i(-1, -2),
]

func _slide_moves(from: Vector2i, directions: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var side := get_piece(from).side
	
	for dir in directions:
		var pos := from + dir
		while is_inside(pos):
			var target := get_piece(pos)
			if target == null:
				result.append(pos)
			else:
				if target.side != side:
					result.append(pos)    # 상대 기물은 잡을 수 있음
				break                      # 아군이든 적이든 여기서 막힘
			pos += dir
	
	return result

func _step_moves(from: Vector2i, offsets: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var side := get_piece(from).side
	
	for offset in offsets:
		var pos := from + offset
		if not is_inside(pos):
			continue
		var target := get_piece(pos)
		if target == null or target.side != side:
			result.append(pos)
	
	return result
	
func _pawn_moves(from: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var piece := get_piece(from)
	var dir := -1 if piece.side == Piece.Side.WHITE else 1
	
	# 1. 한 칸 전진 (빈 칸일 때만)
	var one := from + Vector2i(0, dir)
	if is_inside(one) and is_empty(one):
		result.append(one)
		
		# 2. 두 칸 전진 (첫 수이고, 한 칸도 두 칸도 비었을 때)
		var two := from + Vector2i(0, dir * 2)
		if not piece.has_moved and is_inside(two) and is_empty(two):
			result.append(two)
	
	# 3. 대각선 잡기 (상대 기물이 있을 때만)
	for dx in [-1, 1]:
		var diag := from + Vector2i(dx, dir)
		if not is_inside(diag):
			continue
		var target := get_piece(diag)
		if target != null and target.side != piece.side:
			result.append(diag)
	
	return result
	
func get_moves(from: Vector2i) -> Array[Vector2i]:
	var piece := get_piece(from)
	if piece == null:
		return []
	
	match piece.type:
		Piece.Type.PAWN:
			return _pawn_moves(from)
		Piece.Type.KNIGHT:
			return _step_moves(from, KNIGHT_OFFSETS)
		Piece.Type.KING:
			return _step_moves(from, DIR_ALL)
		Piece.Type.BISHOP:
			return _slide_moves(from, DIR_DIAGONAL)
		Piece.Type.ROOK:
			return _slide_moves(from, DIR_STRAIGHT)
		Piece.Type.QUEEN:
			return _slide_moves(from, DIR_ALL)
	
	return []
			

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
	set_piece(Vector2i(4, 7), Piece.new(Piece.Type.KING, Piece.Side.WHITE))    # e1
	set_piece(Vector2i(4, 5), Piece.new(Piece.Type.BISHOP, Piece.Side.WHITE))  # e3
	set_piece(Vector2i(4, 0), Piece.new(Piece.Type.ROOK, Piece.Side.BLACK))    # e8
	set_piece(Vector2i(0, 0), Piece.new(Piece.Type.KING, Piece.Side.BLACK))    # a8
	#for col in SIZE:
		#set_piece(Vector2i(col, 0), Piece.new(BACK_RANK[col], Piece.Side.BLACK))
		#set_piece(Vector2i(col, 1), Piece.new(Piece.Type.PAWN, Piece.Side.BLACK))
		#set_piece(Vector2i(col, 6), Piece.new(Piece.Type.PAWN, Piece.Side.WHITE))
		#set_piece(Vector2i(col, 7), Piece.new(BACK_RANK[col], Piece.Side.WHITE))

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
	
func copy() -> ChessBoard:
	var c := ChessBoard.new()
	c.clear()
	for row in SIZE:
		for col in SIZE:
			var piece: Piece = board[row][col]
			if piece != null:
				c.board[row][col] = piece.copy()
	c.turn = turn
	c.move_count = move_count
	return c
	
func find_king(side: Piece.Side) -> Vector2i:
	for row in SIZE:
		for col in SIZE:
			var piece: Piece = board[row][col]
			if piece != null and piece.side == side and piece.type == Piece.Type.KING:
				return Vector2i(col, row)
	return Vector2i(-1, -1)

func is_attacked(pos: Vector2i, by_side: Piece.Side) -> bool:
	for row in SIZE:
		for col in SIZE:
			var from := Vector2i(col, row)
			var piece := get_piece(from)
			if piece == null or piece.side != by_side:
				continue
			if pos in get_moves(from):
				return true
	return false

func is_in_check(side: Piece.Side) -> bool:
	var king_pos := find_king(side)
	if not is_inside(king_pos):
		return false
	return is_attacked(king_pos, opponent(side))

func opponent(side: Piece.Side) -> Piece.Side:
	return Piece.Side.BLACK if side == Piece.Side.WHITE else Piece.Side.WHITE
	
func get_legal_moves(from: Vector2i) -> Array[Vector2i]:
	var piece := get_piece(from)
	if piece == null:
		return []
	
	var result: Array[Vector2i] = []
	
	for to in get_moves(from):
		var test := copy()
		test.move_piece(from, to)
		if not test.is_in_check(piece.side):
			result.append(to)
	
	return result
