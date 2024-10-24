extends Node2D

# Called when the node enters the scene tree for the first time.
func _ready():
	init_deck()
	deal_cards()
	place_stock_pile()

func init_deck():
	for suit in range(0, 4):
		for value in range(0, 13):
			var card = preload("res://scenes/Card.tscn").instantiate()
			card.value = value
			card.suit = suit
			GameManager.deck.append(card)
	seed(1)
	GameManager.deck.shuffle()

func get_empty_card():
	var card = preload("res://scenes/Card.tscn").instantiate()
	# Empty card does not have value
	card.value = -1
	card.suit = -1
	card.flip()
	return card

func deal_cards():
	for i in range(GameManager.NO_OF_PILES):
		var pile = GameManager.piles[i]
		
		# Place empty card at the begining of the pile.
		# This card cannot be moved, nor used in movement
		var empty_card = get_empty_card()
		empty_card.pile_id = i
		empty_card.position = GameManager.get_pile_position(i, 0, GameManager.PILE_X_OFFSET, GameManager.PILE_Y_OFFSET)
		pile.append(empty_card)
		add_child(empty_card)
		
		for j in range(0, i + 1):
			var card = GameManager.deck.pop_back()
			card.z_index = j
			if j == i:
				# Flip the top-most card
				card.flip()
			card.position = GameManager.get_pile_position(i, j, GameManager.PILE_X_OFFSET, GameManager.PILE_Y_OFFSET)
			card.pile_id = i
			pile.append(card)
			add_child(card)

func place_stock_pile():
	# Place the remaining cards on a stock side
	for i in range(len(GameManager.deck) - 1):
		var card = GameManager.deck[i]
		card.stock = true
		card.position = GameManager.get_pile_position(
			0, 0, GameManager.PILE_X_OFFSET - 200, GameManager.PILE_Y_OFFSET
		)
		add_child(card)
	
	# Place the last card from set below the deck for use
	var last_card = GameManager.deck[-1]
	last_card.stock = false
	last_card.flip()
	last_card.position = GameManager.get_pile_position(
		0, 0, GameManager.PILE_X_OFFSET - 200, GameManager.PILE_Y_OFFSET + 200
	)
	add_child(last_card)
