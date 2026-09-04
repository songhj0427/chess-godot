class_name ChessBoard
extends RefCounted

# ─────────────────────────────────────────────
# 상수
# ─────────────────────────────────────────────

const SIZE := 8

const BACK_RANK := [
	Piece.Type.ROOK, Piece.Type.KNIGHT, Piece.Type.BISHOP, Piece.Type.QUEEN,
	Piece.Type.KING, Piece.Type.BISHOP, Piece.Type.KNIGHT, Piece.Type.ROOK,
]

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

# 캐슬링 권리 판정에 쓰는 킹/룩의 시작 칸
const CASTLING_SQUARES := [
	Vector2i(4, 7), Vector2i(0, 7), Vector2i(7, 7),
	Vector2i(4, 0), Vector2i(0, 0), Vector2i(7, 0),
]

enum Result {
	ONGOING,
	WHITE_WINS,
	BLACK_WINS,
	DRAW_STALEMATE,
	DRAW_MATERIAL,
	DRAW_FIFTY,
	DRAW_REPETITION,
}

# ─────────────────────────────────────────────
# 상태
# ─────────────────────────────────────────────

var board: Array = []
var turn: Piece.Side = Piece.Side.WHITE
var move_count: int = 0
var en_passant_target: Vector2i = Vector2i(-1, -1)
var promotion_choice: Piece.Type = Piece.Type.QUEEN
var halfmove_clock: int = 0
var position_history: Dictionary = {}
var cached_result: Result = Result.ONGOING

# ─────────────────────────────────────────────
# 초기화
# ─────────────────────────────────────────────

func _init() -> void:
	clear()


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
	en_passant_target = Vector2i(-1, -1)
	promotion_choice = Piece.Type.QUEEN
	halfmove_clock = 0
	position_history = {}

	for col in SIZE:
		set_piece(Vector2i(col, 0), Piece.new(BACK_RANK[col], Piece.Side.BLACK))
		set_piece(Vector2i(col, 1), Piece.new(Piece.Type.PAWN, Piece.Side.BLACK))
		set_piece(Vector2i(col, 6), Piece.new(Piece.Type.PAWN, Piece.Side.WHITE))
		set_piece(Vector2i(col, 7), Piece.new(BACK_RANK[col], Piece.Side.WHITE))
		
	record_position()
	update_result()

# ─────────────────────────────────────────────
# 칸 접근
# ─────────────────────────────────────────────

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


func opponent(side: Piece.Side) -> Piece.Side:
	return Piece.Side.BLACK if side == Piece.Side.WHITE else Piece.Side.WHITE

# ─────────────────────────────────────────────
# 원시 이동 계산 (체크 검사 없음)
# ─────────────────────────────────────────────

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
				break                     # 아군이든 적이든 여기서 막힘
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

	# 3. 대각선 잡기 (상대 기물이 있거나 앙파상 대상 칸일 때)
	for dx in [-1, 1]:
		var diag := from + Vector2i(dx, dir)
		if not is_inside(diag):
			continue
		if diag == en_passant_target:
			result.append(diag)
			continue
		var target := get_piece(diag)
		if target != null and target.side != piece.side:
			result.append(diag)

	return result


func _castling_moves(from: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var king := get_piece(from)

	if king.has_moved or is_in_check(king.side):
		return result

	for rook_col in [0, 7]:
		var rook_pos := Vector2i(rook_col, from.y)
		var rook := get_piece(rook_pos)
		if rook == null or rook.type != Piece.Type.ROOK:
			continue
		if rook.side != king.side or rook.has_moved:
			continue

		var step := 1 if rook_col == 7 else -1

		# 킹과 룩 사이가 비었는가
		var blocked := false
		var check_col := from.x + step
		while check_col != rook_col:
			if not is_empty(Vector2i(check_col, from.y)):
				blocked = true
				break
			check_col += step
		if blocked:
			continue

		# 킹이 지나는 칸과 도착 칸이 안전한가
		var pass_pos := from + Vector2i(step, 0)
		var dest_pos := from + Vector2i(step * 2, 0)
		if is_attacked(pass_pos, opponent(king.side)):
			continue
		if is_attacked(dest_pos, opponent(king.side)):
			continue

		result.append(dest_pos)

	return result


func _move_castling_rook(from: Vector2i, to: Vector2i) -> void:
	var step := 1 if to.x > from.x else -1
	var rook_col := 7 if step == 1 else 0
	var rook_pos := Vector2i(rook_col, from.y)
	var rook := get_piece(rook_pos)
	if rook == null:
		return
	set_piece(from + Vector2i(step, 0), rook)
	set_piece(rook_pos, null)
	rook.has_moved = true


func get_moves(from: Vector2i, include_castling: bool = true) -> Array[Vector2i]:
	var piece := get_piece(from)
	if piece == null:
		return []

	match piece.type:
		Piece.Type.PAWN:
			return _pawn_moves(from)
		Piece.Type.KNIGHT:
			return _step_moves(from, KNIGHT_OFFSETS)
		Piece.Type.KING:
			var moves := _step_moves(from, DIR_ALL)
			if include_castling:
				moves += _castling_moves(from)
			return moves
		Piece.Type.BISHOP:
			return _slide_moves(from, DIR_DIAGONAL)
		Piece.Type.ROOK:
			return _slide_moves(from, DIR_STRAIGHT)
		Piece.Type.QUEEN:
			return _slide_moves(from, DIR_ALL)

	return []

# ─────────────────────────────────────────────
# 공격 판정
# ─────────────────────────────────────────────

func get_attack_squares(from: Vector2i) -> Array[Vector2i]:
	var piece := get_piece(from)
	if piece == null:
		return []

	# 폰은 전진이 아니라 대각선만 공격한다
	if piece.type == Piece.Type.PAWN:
		var result: Array[Vector2i] = []
		var dir := -1 if piece.side == Piece.Side.WHITE else 1
		for dx in [-1, 1]:
			var diag := from + Vector2i(dx, dir)
			if is_inside(diag):
				result.append(diag)
		return result

	# 캐슬링으로는 잡을 수 없으므로 제외 (무한 재귀 방지)
	return get_moves(from, false)


func is_attacked(pos: Vector2i, by_side: Piece.Side) -> bool:
	for row in SIZE:
		for col in SIZE:
			var from := Vector2i(col, row)
			var piece := get_piece(from)
			if piece == null or piece.side != by_side:
				continue
			if pos in get_attack_squares(from):
				return true
	return false


func find_king(side: Piece.Side) -> Vector2i:
	for row in SIZE:
		for col in SIZE:
			var piece: Piece = board[row][col]
			if piece != null and piece.side == side and piece.type == Piece.Type.KING:
				return Vector2i(col, row)
	return Vector2i(-1, -1)


func is_in_check(side: Piece.Side) -> bool:
	var king_pos := find_king(side)
	if not is_inside(king_pos):
		return false
	return is_attacked(king_pos, opponent(side))

# ─────────────────────────────────────────────
# 합법 이동
# ─────────────────────────────────────────────

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


func has_any_legal_move(side: Piece.Side) -> bool:
	for row in SIZE:
		for col in SIZE:
			var from := Vector2i(col, row)
			var piece := get_piece(from)
			if piece == null or piece.side != side:
				continue
			if not get_legal_moves(from).is_empty():
				return true
	return false

# ─────────────────────────────────────────────
# 이동 실행
# ─────────────────────────────────────────────

func move_piece(from: Vector2i, to: Vector2i) -> void:
	var piece := get_piece(from)
	if piece == null:
		return

	# 50수 규칙 판정은 반드시 이동 전에
	var is_capture := not is_empty(to)
	var is_pawn_move := piece.type == Piece.Type.PAWN

	# 앙파상 실행: 폰이 통과 칸으로 갔다면 지나가며 잡은 것
	if piece.type == Piece.Type.PAWN and to == en_passant_target:
		set_piece(Vector2i(to.x, from.y), null)
		is_capture = true

	# 다음 턴을 위한 통과 칸 기록 (대입은 마지막에)
	var new_target := Vector2i(-1, -1)
	if piece.type == Piece.Type.PAWN and absi(to.y - from.y) == 2:
		new_target = Vector2i(from.x, (from.y + to.y) / 2)

	# 캐슬링: 킹이 두 칸 움직였다면 룩도 옮긴다
	if piece.type == Piece.Type.KING and absi(to.x - from.x) == 2:
		_move_castling_rook(from, to)

	set_piece(to, piece)
	set_piece(from, null)
	piece.has_moved = true

	# 승격
	if piece.type == Piece.Type.PAWN and (to.y == 0 or to.y == SIZE - 1):
		piece.type = promotion_choice

	en_passant_target = new_target

	if is_capture or is_pawn_move:
		halfmove_clock = 0
	else:
		halfmove_clock += 1


func switch_turn() -> void:
	turn = Piece.Side.BLACK if turn == Piece.Side.WHITE else Piece.Side.WHITE
	move_count += 1

# ─────────────────────────────────────────────
# 복사
# ─────────────────────────────────────────────

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
	c.en_passant_target = en_passant_target
	c.promotion_choice = promotion_choice
	c.halfmove_clock = halfmove_clock
	c.position_history = position_history.duplicate()
	c.cached_result = cached_result
	return c

# ─────────────────────────────────────────────
# 국면 기록 (3회 반복 판정용)
# ─────────────────────────────────────────────

func get_position_key() -> String:
	var parts: Array = []

	for row in SIZE:
		for col in SIZE:
			var piece: Piece = board[row][col]
			if piece == null:
				parts.append("-")
			else:
				var s := "w" if piece.side == Piece.Side.WHITE else "b"
				parts.append(s + str(piece.type))

	parts.append("t" + str(turn))
	parts.append("e" + str(en_passant_target))

	for pos in CASTLING_SQUARES:
		var p := get_piece(pos)
		parts.append("1" if p != null and not p.has_moved else "0")

	return "|".join(parts)


func record_position() -> void:
	var key := get_position_key()
	position_history[key] = position_history.get(key, 0) + 1

# ─────────────────────────────────────────────
# 종료 판정
# ─────────────────────────────────────────────

func is_checkmate(side: Piece.Side) -> bool:
	return is_in_check(side) and not has_any_legal_move(side)


func is_stalemate(side: Piece.Side) -> bool:
	return not is_in_check(side) and not has_any_legal_move(side)


func is_fifty_move_draw() -> bool:
	return halfmove_clock >= 100


func is_threefold_repetition() -> bool:
	return position_history.get(get_position_key(), 0) >= 3


func is_insufficient_material() -> bool:
	var minor_pieces: Array[Piece] = []
	var minor_positions: Array[Vector2i] = []

	for row in SIZE:
		for col in SIZE:
			var piece: Piece = board[row][col]
			if piece == null or piece.type == Piece.Type.KING:
				continue
			# 폰·룩·퀸이 하나라도 있으면 메이트 가능
			if piece.type in [Piece.Type.PAWN, Piece.Type.ROOK, Piece.Type.QUEEN]:
				return false
			minor_pieces.append(piece)
			minor_positions.append(Vector2i(col, row))

	# 킹 대 킹 / 킹+마이너 하나 대 킹
	if minor_pieces.size() <= 1:
		return true

	# 킹+비숍 대 킹+비숍 (두 비숍이 같은 색 칸)
	if minor_pieces.size() == 2:
		var a := minor_pieces[0]
		var b := minor_pieces[1]
		if a.type == Piece.Type.BISHOP and b.type == Piece.Type.BISHOP and a.side != b.side:
			var color_a := (minor_positions[0].x + minor_positions[0].y) % 2
			var color_b := (minor_positions[1].x + minor_positions[1].y) % 2
			return color_a == color_b

	return false

# ─────────────────────────────────────────────
# 결과 캐싱
# ─────────────────────────────────────────────

func update_result() -> void:
	cached_result = _compute_result()


func get_result() -> Result:
	return cached_result


func is_game_over() -> bool:
	return cached_result != Result.ONGOING


func _compute_result() -> Result:
	# 순서가 규칙을 정한다. 승부가 무승부보다 우선.
	if is_checkmate(turn):
		return Result.BLACK_WINS if turn == Piece.Side.WHITE else Result.WHITE_WINS
	if is_stalemate(turn):
		return Result.DRAW_STALEMATE
	if is_insufficient_material():
		return Result.DRAW_MATERIAL
	if is_fifty_move_draw():
		return Result.DRAW_FIFTY
	if is_threefold_repetition():
		return Result.DRAW_REPETITION
	return Result.ONGOING
