extends Control

@onready var gold_label: Label = %GoldLabel
@onready var items_list: ItemList = %ItemsList
@onready var buy_button: Button = %BuyButton
@onready var continue_button: Button = %ContinueButton

var rolled_items: Array[String] = []
const BATTLE_SCENE_PATH := "res://scenes/BattleScene.tscn"

func _ready() -> void:
    _roll_items()
    _refresh_ui()
    buy_button.pressed.connect(_on_buy_pressed)
    continue_button.pressed.connect(_on_continue_pressed)

func _roll_items() -> void:
    rolled_items.clear()
    var equip_ids: Array[String] = []
    var fallback_ids: Array[String] = []
    for id in DataRegistry.items.keys():
        var def := DataRegistry.items[id]
        if def.has("slot") and def.slot in ["weapon","armor","accessory"]:
            equip_ids.append(id)
        else:
            fallback_ids.append(id)
    var src := equip_ids if equip_ids.size() >= 3 else (equip_ids + fallback_ids)
    src.shuffle()
    for i in range(min(3, src.size())):
        rolled_items.append(src[i])

func _refresh_ui() -> void:
    if Engine.has_singleton("GameManager"):
        gold_label.text = "Gold: %d" % int(GameManager.gold)
    else:
        gold_label.text = "Gold: (n/a)"
    items_list.clear()
    for id in rolled_items:
        var def := DataRegistry.items.get(id, {})
        var label := "%s" % def.get("name", id.capitalize())
        var idx := items_list.add_item(label)
        items_list.set_item_metadata(idx, id)

func _on_buy_pressed() -> void:
    var sel := items_list.get_selected_items()
    if sel.is_empty(): return
    var id: String = String(items_list.get_item_metadata(sel[0]))
    var def := DataRegistry.items.get(id, {})
    var price := int(def.get("price", 30)) # simple default
    # use GameManager.gold if available; otherwise skip gold check
    if Engine.has_singleton("GameManager"):
        if GameManager.gold < price:
            push_warning("Not enough gold.")
            return
        GameManager.gold -= price
    RunManager.inventory[id] = int(RunManager.inventory.get(id, 0)) + 1
    if Engine.has_singleton("SaveService"):
        SaveService.save_snapshot({"inventory": RunManager.inventory, "gold": GameManager.gold if Engine.has_singleton("GameManager") else 0})
    _refresh_ui()

func _on_continue_pressed() -> void:
    get_tree().change_scene_to_file(BATTLE_SCENE_PATH)
