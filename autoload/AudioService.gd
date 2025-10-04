extends Node

var audio_player: AudioStreamPlayer

func _ready() -> void:
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)

func play_sfx(sound_name: String) -> void:
	# For now, just print the sound name since we don't have actual sound files
	print("Playing SFX: ", sound_name)
	
	# If you want to add actual sound files later, you can do:
	# var sound_path = "res://audio/sfx/" + sound_name + ".wav"
	# if FileAccess.file_exists(sound_path):
	#     audio_player.stream = load(sound_path)
	#     audio_player.play()