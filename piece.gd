class_name Piece
extends RefCounted

enum Type { PAWN, KNIGHT, BISHOP, ROOK, QUEEN, KING }
enum Side { WHITE, BLACK }

var type: Piece.Type
var side: Piece.Side
var has_moved: bool = false

func _init(p_type: Piece.Type, p_side: Piece.Side) -> void:
	type = p_type
	side = p_side

func copy() -> Piece:
	var c := Piece.new(type, side)
	c.has_moved = has_moved
	return c
