@tool
extends EditorScript

const SOURCE := "res://_portraits_in/"
const DST := "res://art/portraits/"

func _run() -> void:
	var da := DirAccess.open(SOURCE)
	if da == null:
		push_error("Missing folder: %s" % SOURCE)
		return
	
	da.list_dir_begin()
	var fn := da.get_next()
	while fn != "":
		if not fn.begins_with(".") and not da.current_is_dir():
			var src := SOURCE + fn
			var img := Image.load_from_file(src)
			if img:
				var w := img.get_width()
				var h := img.get_height()
				var side := min(w, h)
				var x := int((w - side) / 2)
				var y := int((h - side) / 2)
				
				var sq: Image = Image.create(side, side, false, img.get_format())
				if sq:
					sq.blit_rect(img, Rect2i(x, y, side, side), Vector2i(0, 0))
					sq.resize(96, 96, Image.INTERPOLATE_LANCZOS)
					
					var key := fn.get_basename().to_lower()
					var out := "%s%s_portrait_96.png" % [DST, key]
					var save_err: Error = sq.save_png(out)
					if save_err == OK:
						print("Wrote: ", out)
					else:
						push_error("Failed to save: %s (Error code: %d)" % [out, save_err])
		fn = da.get_next()
	
	da.list_dir_end()
