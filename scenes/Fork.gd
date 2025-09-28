extends Control

signal pick(kind: String)

@onready var btn_battle: Button = $VBox/BtnBattle
@onready var btn_shop:   Button = $VBox/BtnShop
@onready var btn_event:  Button = $VBox/BtnEvent

func _ready() -> void:
	btn_battle.pressed.connect(func(): emit_signal("pick", "battle"))
	btn_shop.pressed.connect(func(): emit_signal("pick", "shop"))
	btn_event.pressed.connect(func(): emit_signal("pick", "event"))
