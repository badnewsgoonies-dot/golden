extends Control

var items = [
	{"name": "Potion", "cost": 50, "description": "Heals 50 HP."},
	{"name": "Phoenix Down", "cost": 200, "description": "Revives a fallen ally."},
	{"name": "Ether", "cost": 75, "description": "Restores 20 MP."}
]

@onready var gold_label = $VBoxContainer/GoldLabel
@onready var item_list = $VBoxContainer/ItemList

func _ready():
	update_gold_label()
	populate_item_list()

func update_gold_label():
	gold_label.text = "Gold: " + str(GameManager.gold)

func populate_item_list():
	for item in items:
		var item_entry = HBoxContainer.new()
		
		var name_label = Label.new()
		name_label.text = item.name
		item_entry.add_child(name_label)
		
		var cost_label = Label.new()
		cost_label.text = "Cost: " + str(item.cost)
		item_entry.add_child(cost_label)
		
		var buy_button = Button.new()
		buy_button.text = "Buy"
		buy_button.pressed.connect(_on_buy_button_pressed.bind(item))
		item_entry.add_child(buy_button)
		
		item_list.add_child(item_entry)

func _on_buy_button_pressed(item):
	if GameManager.gold >= item.cost:
		GameManager.gold -= item.cost
		RunManager.add_item(item.name.to_lower())
		update_gold_label()
		print("Bought " + item.name)
	else:
		print("Not enough gold!")

func _on_return_button_pressed():
	get_tree().change_scene_to_file("res://scenes/BattleScene.tscn")
