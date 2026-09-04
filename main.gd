extends Node2D

# ─────────────────────────────────────────────
# 판 배치
# ─────────────────────────────────────────────

const BOARD_SIZE := 8
const SQUARE_SIZE := 80
const BOARD_OFFSET := Vector2(80, 80)

const COLOR_LIGHT := Color("f0d9b5")
const COLOR_DARK := Color("b58863")
const COLOR_SELECT := Color(0.4, 0.8, 0.4, 0.5)
const COLOR_MOVE := Color(0.2, 0.5, 0.2, 0.35)
const COLOR_CAPTURE := Color(0.8, 0.2, 0.2, 0.4)
const COLOR_CHECK := Color(0.9, 0.1, 0.1, 0.45)

# ─────────────────────────────────────────────
# 기물 스프라이트 시트
# ─────────────────────────────────────────────

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

# ─────────────────────────────────────────────
# 결과 문구
# ─────────────────────────────────────────────

const RESULT_TEXT := {
	ChessBoard.Result.WHITE_WINS: "체크메이트 — 백 승리",
	ChessBoard.Result.BLACK_WINS: "체크메이트 — 흑 승리",
	ChessBoard.Result.DRAW_STALEMATE: "스테일메이트 — 무승부",
	ChessBoard.Result.DRAW_MATERIAL: "기물 부족 — 무승부",
	ChessBoard.Result.DRAW_FIFTY: "50수 규칙 — 무승부",
	ChessBoard.Result.DRAW_REPETITION: "3회 반복 — 무승부",
}

const PROMOTION_TYPES := [
	Piece.Type.QUEEN, Piece.Type.ROOK, Piece.Type.BISHOP, Piece.Type.KNIGHT,
]

# ─────────────────────────────────────────────
# 노드와 상태
# ─────────────────────────────────────────────

@onready var board_visual: Node2D = $BoardVisual
@onready var piece_visual: Node2D = $PieceVisual
@onready var highlight_visual: Node2D = $HighlightVisual

var chess_board := ChessBoard.new()

var selected: Vector2i = Vector2i(-1, -1)
var legal_moves: Array[Vector2i] = []
var textures: Dictionary = {}
var awaiting_promotion: bool = false

signal promotion_selected(type: Piece.Type)

# ─────────────────────────────────────────────
# 좌표 변환
# ─────────────────────────────────────────────

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

# ─────────────────────────────────────────────
# 준비
# ─────────────────────────────────────────────

func _ready() -> void:
	_load_textures()
	_create_board()
	_setup_promotion_panel()
	chess_board.setup_initial()
	_refresh()


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
			atlas.region = Rect2(Vector2(col, SHEET_SIDE_ROW[side]) * cell, cell)

			var key: String = "%s_%s" % [SIDE_NAMES[side], TYPE_NAMES[SHEET_ORDER[col]]]
			textures[key] = atlas


func _create_board() -> void:
	for row in BOARD_SIZE:
		for col in BOARD_SIZE:
			var square := ColorRect.new()
			square.size = Vector2(SQUARE_SIZE, SQUARE_SIZE)
			square.position = board_to_screen(Vector2i(col, row))
			square.color = COLOR_LIGHT if (row + col) % 2 == 0 else COLOR_DARK
			square.mouse_filter = Control.MOUSE_FILTER_IGNORE
			board_visual.add_child(square)


func _setup_promotion_panel() -> void:
	%PromotionPanel.hide()
	var buttons := %PromotionPanel.get_node("HBoxContainer").get_children()
	for i in mini(buttons.size(), PROMOTION_TYPES.size()):
		buttons[i].pressed.connect(_on_promotion_button.bind(PROMOTION_TYPES[i]))

# ─────────────────────────────────────────────
# 입력
# ─────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if awaiting_promotion:
		return
	if event is not InputEventMouseButton:
		return
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return

	var cell := screen_to_board(event.position)
	if is_inside(cell):
		_on_cell_clicked(cell)


func _on_cell_clicked(cell: Vector2i) -> void:
	if chess_board.is_game_over():
		return

	var clicked_piece := chess_board.get_piece(cell)

	if not is_inside(selected):
		# 상태 1: 선택 없음 — 고르기
		if clicked_piece != null and clicked_piece.side == chess_board.turn:
			_select(cell)
	else:
		# 상태 2: 선택 있음
		if cell == selected:
			_deselect()                                    # 같은 칸 → 선택 해제
		elif clicked_piece != null and clicked_piece.side == chess_board.turn:
			_select(cell)                                  # 내 다른 기물 → 선택 변경
		elif cell in legal_moves:
			await _do_move(selected, cell)                 # 그 외 → 이동
		# 갈 수 없는 칸이면 아무것도 안 함

	_refresh()


func _do_move(from: Vector2i, to: Vector2i) -> void:
	var piece := chess_board.get_piece(from)
	var is_promotion := piece.type == Piece.Type.PAWN and (to.y == 0 or to.y == BOARD_SIZE - 1)

	if is_promotion:
		chess_board.promotion_choice = await _ask_promotion()

	chess_board.move_piece(from, to)
	chess_board.switch_turn()
	chess_board.record_position()
	chess_board.update_result()
	_deselect()


func _ask_promotion() -> Piece.Type:
	awaiting_promotion = true
	%PromotionPanel.show()
	var choice: Piece.Type = await promotion_selected
	%PromotionPanel.hide()
	awaiting_promotion = false
	return choice


func _on_promotion_button(type: Piece.Type) -> void:
	promotion_selected.emit(type)


func _select(cell: Vector2i) -> void:
	selected = cell
	legal_moves = chess_board.get_legal_moves(cell)


func _deselect() -> void:
	selected = Vector2i(-1, -1)
	legal_moves = []

# ─────────────────────────────────────────────
# 화면 갱신
# ─────────────────────────────────────────────

func _refresh() -> void:
	_update_pieces()
	_update_highlight()
	_update_ui()


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


func _update_highlight() -> void:
	for child in highlight_visual.get_children():
		child.queue_free()

	# 체크 표시를 먼저 그려서 뒤에 깔리게 한다
	if chess_board.is_in_check(chess_board.turn):
		var king_pos := chess_board.find_king(chess_board.turn)
		if chess_board.is_inside(king_pos):
			_add_highlight(king_pos, COLOR_CHECK)

	if not is_inside(selected):
		return

	_add_highlight(selected, COLOR_SELECT)

	for move in legal_moves:
		var color := COLOR_CAPTURE if not chess_board.is_empty(move) else COLOR_MOVE
		_add_highlight(move, color)


func _add_highlight(pos: Vector2i, color: Color) -> void:
	var rect := ColorRect.new()
	rect.size = Vector2(SQUARE_SIZE, SQUARE_SIZE)
	rect.position = board_to_screen(pos)
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	highlight_visual.add_child(rect)


func _update_ui() -> void:
	var result := chess_board.get_result()

	if result != ChessBoard.Result.ONGOING:
		%TurnLabel.text = RESULT_TEXT[result]
		return

	var side_name: String = "백" if chess_board.turn == Piece.Side.WHITE else "흑"
	var text := "%s 차례 (%d수)" % [side_name, chess_board.move_count]
	if chess_board.is_in_check(chess_board.turn):
		text += "  — 체크!"
	%TurnLabel.text = text
