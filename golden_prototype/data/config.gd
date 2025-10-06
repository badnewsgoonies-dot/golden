
# data/config.gd
extends Resource
class_name BattleConfig

const TILE_W := 64
const TILE_H := 32

const FPS_IDLE := 8.0
const FPS_HIT := 12.0
const FPS_ATTACK := 12.0
const FPS_CAST := 10.0
const FPS_GUARD := 8.0
const FPS_KO := 10.0

const TURN_SPEED_BASE := 100.0
const TURN_SPEED_VARIANCE := 0.2

const COLOR_HP := Color8(210, 46, 46)
const COLOR_MP := Color8(40, 170, 230)
const COLOR_UI := Color8(255, 237, 106)
