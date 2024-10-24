extends Area2D

var value = 0
var suit = 0
var flipped:bool = false
var is_dragging:bool = false # Whether card is being dragged

var pile_id = null # Keep track of on what pile is the card placed in.
var stock:bool = false # Keep track whether the card is in stock set
var is_mouse_entered:bool = false
var previous_positions = [] # Old Positions of cards being moved

@onready var sprite:Sprite2D = $Sprite2D

# Called when the node enters the scene tree for the first time.
func _ready():
	update_sprite()

func _input(event):
	# Handle all card drag events
	
	# don't move card if mouse is not on the card
	# don't move empty card
	if not is_mouse_entered or (suit == -1 and value == -1):
		return
		
	# When user presses on stock then we need to shuffle top cards
	if Input.is_action_just_pressed("left_click") and stock:
		update_stock_top()
		return
	
	# Can move only the top card
	if Input.is_action_just_pressed("left_click") and flipped:
		is_dragging = true
		# If user doesn't want to move card or is doing invalid move, then we need to reset positions of selected cards
		remember_card_positions()
	elif event is InputEventMouseMotion and is_dragging:
		move_cards()
	elif Input.is_action_just_released("left_click") and is_dragging:
		is_dragging = false
		if !drop_card():
			reset_cards()
		
func update_sprite():
	if sprite:
		sprite.texture = get_texture()
		if suit == -1 and value == -1:
			sprite.hide()
		
func get_texture():
	if not flipped or (suit == -1 and value == -1):
		return preload("res://card_assets/Back1.png")

	var res_path = "res://card_assets/{value}.{suit}.png".format({
		"value": str(value + 1),
		"suit": str(suit + 1)
	})
	return load(res_path)
	
func flip():
	flipped = !flipped
	update_sprite()

# Game Logic

func check_valid_move(card):
	# Don't move in same pile or back to Stock
	if card.pile_id == null or card.pile_id == pile_id:
		return false
	
	var pile = GameManager.piles[card.pile_id]
	
	# Empty pile - it's hard to detect an empty pile when we don't have marker. 
	# so we will use a hack to detect a card as empty pile
	if len(pile) == 1 and card.suit == -1 and card.value == -1:
		return true # we can move cards to an empty pile
	
	# don't place card on top of unflipped card
	if not card.flipped:
		return false
		
	# the card where we are going to place should be one more in value and has opposite colored suit
	# select top card in the pile where we are going place the current set, hence pile[-1]
	if value == pile[-1].value - 1 and suit % 2 != pile[-1].suit % 2:
		return true
	
	return false

func move_to_new_pile(new_card):
	# Move pile card
	if pile_id != null:
		var current_pile = GameManager.piles[pile_id]
		var current_card_index = current_pile.find(self)
		
		var new_pile = GameManager.piles[new_card.pile_id]
		
		# Move cards from current_pile to new_pile
		var cards_to_move = current_pile.slice(current_card_index, len(current_pile))
		for i in range(len(cards_to_move)):
			var card = cards_to_move[i]
			card.position = GameManager.get_pile_position(
				new_card.pile_id, len(new_pile) - 1,
				GameManager.PILE_X_OFFSET, GameManager.PILE_Y_OFFSET
			)
			card.z_index = new_pile[-1].z_index + 1
			card.pile_id = new_card.pile_id
			new_pile.append(card)
		
		# Remove the top cards from old pile
		for i in range(len(cards_to_move)):
			current_pile.pop_back()
		
		# Flip the top-most card of previous pile after moving
		if len(current_pile) > 1:
			current_pile.back().flip()
	
	# move from stock
	elif pile_id == null:
		var new_pile = GameManager.piles[new_card.pile_id]
		var card = GameManager.deck.pop_back()
		card.stock = false
		card.position = GameManager.get_pile_position(
			new_card.pile_id, len(new_pile) - 1,
			GameManager.PILE_X_OFFSET, GameManager.PILE_Y_OFFSET
		)
		card.z_index = new_pile[-1].z_index + 1
		card.pile_id = new_card.pile_id
		new_pile.append(card)
		
		# Flip card in the stock
		# Only if there are 2 cards or more.
		# 1 card wouldb e the stock itself
		if len(GameManager.deck) > 1:
			var card_on_stock = GameManager.deck[-1]
			card_on_stock.stock = false
			card_on_stock.flip()
			card_on_stock.position = GameManager.get_pile_position(
				0, 0, GameManager.PILE_X_OFFSET - 200, GameManager.PILE_Y_OFFSET + 200
			)
	
	previous_positions = []
	if check_win():
		print("YOU WON!!")

func update_stock_top():
	# Remove current stock top and place it at the beginning of the stock
	var cur_stock_top = GameManager.deck.pop_back()
	cur_stock_top.flip()
	cur_stock_top.stock = true
	var pos = cur_stock_top.position
	cur_stock_top.position = GameManager.deck[0].position
	
	GameManager.deck.insert(0, cur_stock_top)
	
	# The top card out of stock would be already out, so don't include that.
	if len(GameManager.deck) > 1:
		var new_card = GameManager.deck[-1]
		new_card.stock = false
		new_card.flip()
		new_card.position = pos

	

func check_win():
	if len(GameManager.deck) > 0:
		return false
	for pile in GameManager.piles:
		for card in pile:
			if not card.flipped:
				return false
	return true

#### Mouse Movement Functions

func move_cards():
	# Move the selected cards
	if pile_id == null:
		position = get_global_mouse_position()
		z_index = 100 
		return
	
	# First find the selected card
	var pile = GameManager.piles[pile_id]
	var current_card_index = pile.find(self)
	if len(pile) > current_card_index:
		# We need to move selected set of cards
		var cards_to_move = pile.slice(current_card_index, len(pile))
		for i in range(len(cards_to_move)):
			var card = cards_to_move[i]
			card.position = get_global_mouse_position()
			
			# Apply vertical width to separate multiple cards 
			card.position.y += 30 * i
			
			# Apply high z-index to have the moving card appear infront of all other piles
			card.z_index = 100 + i

func drop_card():
	# If card is moved to a valid set, then we need to move it.
	var overlapping_areas = get_overlapping_areas()
	for area in overlapping_areas:
		# Need to detect other card
		if area.is_in_group("card"):
			if check_valid_move(area):
				move_to_new_pile(area)
				return true

	# If cards cannot be moved, then we need to reset the state
	return false

func remember_card_positions():
	previous_positions = []
	# Stock cards are not part of pile
	if pile_id == null:
		previous_positions.append({
			"position": position
		})
		z_index = 100
		return
		
	var pile = GameManager.piles[pile_id]
	var current_card_index = pile.find(self)
	if len(pile) > current_card_index:
		# We need to move selected set of cards
		var cards_to_move = pile.slice(current_card_index, len(pile))
		for card in cards_to_move:
			previous_positions.append({
				"position": card.position
			})

func reset_cards():
	if pile_id == null:
		position = previous_positions[0]['position']
		z_index = 1
	else:
		var pile = GameManager.piles[pile_id]
		var current_card_index = pile.find(self)
		if len(pile) > current_card_index:
			# We need to reset positions of selected set of cards
			var cards_to_move = pile.slice(current_card_index, len(pile))
			for i in range(len(previous_positions)):
				var card = cards_to_move[i]
				card.position = previous_positions[i]['position']
				card.z_index = pile[current_card_index - 1].z_index + i + 1
	previous_positions = []

func _on_mouse_entered():
	is_mouse_entered = true

func _on_mouse_exited():
	is_mouse_entered = false
