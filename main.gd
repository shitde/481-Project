extends Node2D

const PLAYER = 1
const AI = -1
const EMPTY = 0
const KING_PLAYER = 2
const KING_AI = -2

const BOARD_SIZE_Y = 8
const BOARD_SIZE_X = 10


@onready var tile_map = $TileMapLayer
@onready var piece_container = $PieceContainer
@export var piece_scene: PackedScene
var board = []
var current_turn = PLAYER


func _ready():
	initialize_board()
	draw_board()
	draw_pieces()
	if current_turn == AI:
		ai_turn()

func initialize_board():
	board = []
	for y in range(BOARD_SIZE_Y):
		var row = []
		for x in range(BOARD_SIZE_X):
			if (x + y) % 2 == 1:
				if y < 3:
					row.append(AI)
				elif y > 4:
					row.append(PLAYER)
				else:
					row.append(EMPTY)
			else:
				row.append(EMPTY)
		board.append(row)
		

func draw_board():
	tile_map.clear()
	for y in range(BOARD_SIZE_Y):
		for x in range(BOARD_SIZE_X):
			var coords = Vector2i(x, y)
			var source_id = (x + y) % 2
			tile_map.set_cell(coords, source_id, Vector2i(0, 0))


func draw_pieces():
	for i in piece_container.get_children():
		piece_container.remove_child(i)
		i.queue_free()
	var tile_size = tile_map.tile_set.tile_size
	print(tile_size)

	for y in range(BOARD_SIZE_Y):
		for x in range(BOARD_SIZE_X):
			var val = board[y][x]
			if val != EMPTY:
				var piece = piece_scene.instantiate()
				
				
				var cell_coords = Vector2i(x, y)
				var cell_pos = tile_map.map_to_local(cell_coords)
				piece.position = cell_pos + Vector2(tile_size.x, tile_size.y) / 2.0
				
				piece_container.add_child(piece)
				piece.set_player(val)

#Handel Player Turns

func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed:
		var local_pos = tile_map.to_local(event.position)
		var cell = tile_map.local_to_map(local_pos)
		
		
		print("Click at: ", event.position, " -> Cell: ", cell)
		on_board_click(cell)

var selected_pos = null

func on_board_click(pos):
	if pos.x < 0 or pos.y < 0 or pos.x >= BOARD_SIZE_X or pos.y >= BOARD_SIZE_X:
		return

	if selected_pos == null:
		if board[pos.y][pos.x] == PLAYER or board[pos.y][pos.x] == KING_PLAYER:
			selected_pos = Vector2i(pos.x, pos.y)
	else:
		var move = [selected_pos, Vector2i(pos.x, pos.y)]
		var valid = false
		for m in get_all_moves(board, true):
			if m[0] == move[0] and m[1] == move[1]:
				valid = true
				break
		print("Selected pos:", selected_pos)
		print("Move:", move)
		if valid:
			board = apply_move(board, move)
			current_turn = AI
			selected_pos = null
			draw_board()
			draw_pieces()
			ai_turn()
		else:
			selected_pos = null

func ai_turn():
	var best_move = null
	var best_score = -INF
	for move in get_all_moves(board, false):
		var temp_board = apply_move(board.duplicate(true), move)
		var score = alpha_beta(temp_board, 4, -INF, INF, false)
		if score > best_score:
			best_score = score
			best_move = move
	if best_move:
		board = apply_move(board, best_move)
		draw_pieces()
		current_turn = PLAYER

func alpha_beta(state, depth, alpha, beta, maximizing):
	if depth == 0 or is_game_over(state):
		return evaluate(state)

	if maximizing:
		var max_eval = -INF
		for move in get_all_moves(state, true):
			var eval = alpha_beta(apply_move(state.duplicate(true), move), depth - 1, alpha, beta, false)
			max_eval = max(max_eval, eval)
			alpha = max(alpha, eval)
			if beta <= alpha:
				break
		return max_eval
	else:
		var min_eval = INF
		for move in get_all_moves(state, false):
			var eval = alpha_beta(apply_move(state.duplicate(true), move), depth - 1, alpha, beta, true)
			min_eval = min(min_eval, eval)
			beta = min(beta, eval)
			if beta <= alpha:
				break
		return min_eval

func evaluate(state):
	var score = 0
	for row in state:
		for cell in row:
			match cell:
				PLAYER:
					score += 1
				KING_PLAYER:
					score += 2
				AI:
					score -= 1
				KING_AI:
					score -= 2
	return score

func get_all_moves(state, is_player):
	var moves = []
	for y in range(BOARD_SIZE_Y):
		for x in range(BOARD_SIZE_X):
			var piece = state[y][x]
			if (is_player and piece > 0) or (not is_player and piece < 0):
				moves += get_piece_moves(state, x, y)
	return moves

func get_piece_moves(state, x, y):
	var piece = state[y][x]
	var directions = []
	if abs(piece) == 1:
		if piece > 0:
			directions = [[-1, -1], [1, -1]]
		else:
			directions = [[-1, 1], [1, 1]]
	else:
		directions = [[-1, -1], [1, -1], [-1, 1], [1, 1]]

	var moves = []
	for dir in directions:
		var nx = x + dir[0]
		var ny = y + dir[1]
		if is_in_bounds(nx, ny) and state[ny][nx] == EMPTY:
			moves.append([Vector2i(x, y), Vector2i(nx, ny)])
		elif is_in_bounds(nx + dir[0], ny + dir[1]) and state[ny][nx] != EMPTY and sign(state[ny][nx]) != sign(piece) and state[ny + dir[1]][nx + dir[0]] == EMPTY:
			moves.append([Vector2i(x, y), Vector2i(nx + dir[0], ny + dir[1])])
	return moves

func apply_move(state, move):
	var from_pos = move[0]
	var to_pos = move[1]
	var piece = state[from_pos.y][from_pos.x]
	state[from_pos.y][from_pos.x] = EMPTY
	state[to_pos.y][to_pos.x] = piece

	# Capture code
	if abs(from_pos.x - to_pos.x) == 2:
		var cap_x = int((from_pos.x + to_pos.x) / 2)
		var cap_y = int((from_pos.y + to_pos.y) / 2)
		state[cap_y][cap_x] = EMPTY

	# Promotion
	if to_pos.y == 0 and piece == PLAYER:
		state[to_pos.y][to_pos.x] = KING_PLAYER
	elif to_pos.y == BOARD_SIZE_Y - 1 and piece == AI:
		state[to_pos.y][to_pos.x] = KING_AI
	return state

func is_in_bounds(x, y):
	return x >= 0 and x < BOARD_SIZE_X and y >= 0 and y < BOARD_SIZE_Y

func is_game_over(state):
	return get_all_moves(state, true).is_empty() or get_all_moves(state, false).is_empty()
