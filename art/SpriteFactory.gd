class_name SpriteFactory
extends Node

# Public API
static func make_humanoid(role: String, scale: int = 3) -> Texture2D:
    var pal: Dictionary = _role_palette(role)
    return _build_humanoid(pal, scale)

static func make_humanoid_with_arm(role: String, scale: int = 3) -> Dictionary:
    var pal: Dictionary = _role_palette(role)
    return _build_humanoid_layers(pal, scale)

static func make_monster(kind: String, scale: int = 3) -> Texture2D:
    match kind.to_lower():
        "goblin":
            return _build_goblin(scale)
        "slime":
            return _build_slime(scale)
        "bat":
            return _build_bat(scale)
        _:
            return _build_slime(scale)

# Palettes
static func _role_palette(role: String) -> Dictionary:
    match role.to_lower():
        "adept":
            return {
                "skin": Color(0.93, 0.83, 0.73, 1.0),
                "hair": Color(0.20, 0.12, 0.05, 1.0),
                "cloth1": Color(0.80, 0.30, 0.28, 1.0),
                "cloth2": Color(0.95, 0.85, 0.50, 1.0),
                "boots": Color(0.22, 0.16, 0.10, 1.0),
            }
        "rogue":
            return {
                "skin": Color(0.86, 0.76, 0.66, 1.0),
                "hair": Color(0.12, 0.12, 0.12, 1.0),
                "cloth1": Color(0.25, 0.55, 0.35, 1.0),
                "cloth2": Color(0.15, 0.18, 0.22, 1.0),
                "boots": Color(0.16, 0.14, 0.12, 1.0),
            }
        "cleric":
            return {
                "skin": Color(0.94, 0.86, 0.78, 1.0),
                "hair": Color(0.85, 0.78, 0.55, 1.0),
                "cloth1": Color(0.80, 0.80, 0.92, 1.0),
                "cloth2": Color(0.90, 0.90, 0.95, 1.0),
                "boots": Color(0.30, 0.30, 0.36, 1.0),
            }
        "guard":
            return {
                "skin": Color(0.84, 0.74, 0.64, 1.0),
                "hair": Color(0.35, 0.22, 0.10, 1.0),
                "cloth1": Color(0.55, 0.60, 0.75, 1.0),
                "cloth2": Color(0.40, 0.45, 0.58, 1.0),
                "boots": Color(0.18, 0.18, 0.22, 1.0),
            }
        _:
            return _role_palette("adept")

# Humanoid builder (16x24)
static func _build_humanoid(pal: Dictionary, scale: int) -> Texture2D:
    var w: int = 16
    var h: int = 24
    var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
    img.fill(Color(0, 0, 0, 0))

    # Head
    _fill_rect(img, 5, 2, 6, 6, pal["skin"])
    _fill_rect(img, 5, 1, 6, 2, pal["hair"])
    _fill_rect(img, 4, 2, 2, 2, pal["hair"]) # bangs left
    _fill_rect(img, 11, 2, 1, 2, pal["hair"]) # bangs right

    # Eyes
    _set_px(img, 7, 4, Color(0, 0, 0, 1))
    _set_px(img, 9, 4, Color(0, 0, 0, 1))

    # Torso
    _fill_rect(img, 4, 8, 8, 7, pal["cloth1"])
    _fill_rect(img, 4, 11, 8, 1, pal["cloth2"]) # belt

    # Arms
    _fill_rect(img, 2, 8, 2, 5, pal["cloth1"])
    _fill_rect(img, 12, 8, 2, 5, pal["cloth1"])

    # Hands
    _fill_rect(img, 2, 13, 2, 2, pal["skin"])
    _fill_rect(img, 12, 13, 2, 2, pal["skin"])

    # Legs/boots
    _fill_rect(img, 5, 15, 3, 6, pal["cloth2"])
    _fill_rect(img, 8, 15, 3, 6, pal["cloth2"])
    _fill_rect(img, 5, 20, 3, 2, pal["boots"])
    _fill_rect(img, 8, 20, 3, 2, pal["boots"])

    # Outline
    _outline(img, Color(0, 0, 0, 1))

    return _scaled_texture(img, scale)

static func _build_humanoid_layers(pal: Dictionary, scale: int) -> Dictionary:
    var w: int = 16
    var h: int = 24
    var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
    img.fill(Color(0, 0, 0, 0))

    # Head / hair / eyes
    _fill_rect(img, 5, 2, 6, 6, pal["skin"])
    _fill_rect(img, 5, 1, 6, 2, pal["hair"])
    _fill_rect(img, 4, 2, 2, 2, pal["hair"]) # bangs left
    _fill_rect(img, 11, 2, 1, 2, pal["hair"]) # bangs right
    _set_px(img, 7, 4, Color(0, 0, 0, 1))
    _set_px(img, 9, 4, Color(0, 0, 0, 1))

    # Torso / arms / hands / legs / boots
    _fill_rect(img, 4, 8, 8, 7, pal["cloth1"])  # torso
    _fill_rect(img, 4, 11, 8, 1, pal["cloth2"]) # belt
    _fill_rect(img, 2, 8, 2, 5, pal["cloth1"])  # left arm
    _fill_rect(img, 12, 8, 2, 5, pal["cloth1"]) # right arm
    _fill_rect(img, 2, 13, 2, 2, pal["skin"])   # left hand
    _fill_rect(img, 12, 13, 2, 2, pal["skin"])  # right hand
    _fill_rect(img, 5, 15, 3, 6, pal["cloth2"]) # legs
    _fill_rect(img, 8, 15, 3, 6, pal["cloth2"]) # legs
    _fill_rect(img, 5, 20, 3, 2, pal["boots"])  # boots
    _fill_rect(img, 8, 20, 3, 2, pal["boots"])  # boots
    _outline(img, Color(0, 0, 0, 1))
    var body_tex: Texture2D = _scaled_texture(img, scale)

    # Arm overlay canvas (pivot at 0,0)
    var aw: int = 12
    var ah: int = 8
    var arm_img: Image = Image.create(aw, ah, false, Image.FORMAT_RGBA8)
    arm_img.fill(Color(0, 0, 0, 0))
    _fill_rect(arm_img, 0, 3, 6, 2, pal["cloth1"]) # upper arm around pivot
    _fill_rect(arm_img, 6, 2, 3, 4, pal["skin"])   # forearm/hand
    _fill_rect(arm_img, 9, 3, 3, 2, Color(0.65, 0.62, 0.70, 1.0)) # weapon edge
    _outline(arm_img, Color(0, 0, 0, 1))
    var arm_tex: Texture2D = _scaled_texture(arm_img, scale)

    # Shoulder pivot relative to body center (8,12) -> approx (11,10)
    var px: float = (11.0 - 8.0) * float(scale)
    var py: float = (10.0 - 12.0) * float(scale)

    return {
        "body": body_tex,
        "arm": arm_tex,
        "arm_pivot_local": Vector2(px, py),
    }

# Monsters
static func _build_goblin(scale: int) -> Texture2D:
    var w: int = 16
    var h: int = 16
    var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
    img.fill(Color(0, 0, 0, 0))
    var skin: Color = Color(0.30, 0.62, 0.25, 1)
    _fill_circle(img, 8, 8, 6, skin)
    _fill_rect(img, 1, 6, 2, 3, skin)
    _fill_rect(img, 13, 6, 2, 3, skin)
    _set_px(img, 6, 7, Color(0, 0, 0, 1))
    _set_px(img, 10, 7, Color(0, 0, 0, 1))
    _fill_rect(img, 6, 10, 4, 1, Color(0, 0, 0, 1))
    _outline(img, Color(0, 0, 0, 1))
    return _scaled_texture(img, scale)

static func _build_slime(scale: int) -> Texture2D:
    var w: int = 16
    var h: int = 12
    var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
    img.fill(Color(0, 0, 0, 0))
    var body: Color = Color(0.30, 0.80, 0.95, 0.95)
    _fill_circle(img, 8, 7, 5, body)
    _fill_rect(img, 3, 9, 10, 2, body)
    _set_px(img, 6, 7, Color(0, 0, 0, 0.9))
    _set_px(img, 10, 7, Color(0, 0, 0, 0.9))
    _outline(img, Color(0, 0, 0, 1))
    return _scaled_texture(img, scale)

static func _build_bat(scale: int) -> Texture2D:
    var w: int = 20
    var h: int = 12
    var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
    img.fill(Color(0, 0, 0, 0))
    var body: Color = Color(0.25, 0.22, 0.30, 1)
    _fill_circle(img, 10, 6, 3, body)
    _fill_rect(img, 2, 6, 6, 2, body)
    _fill_rect(img, 12, 6, 6, 2, body)
    _set_px(img, 9, 5, Color(0, 0, 0, 1))
    _set_px(img, 11, 5, Color(0, 0, 0, 1))
    _outline(img, Color(0, 0, 0, 1))
    return _scaled_texture(img, scale)

# Low-level drawing
static func _set_px(img: Image, x: int, y: int, c: Color) -> void:
    if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
        return
    img.set_pixel(x, y, c)

static func _fill_rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
    var x2: int = x + w
    var y2: int = y + h
    for yy in range(y, y2):
        if yy < 0 or yy >= img.get_height():
            continue
        for xx in range(x, x2):
            if xx < 0 or xx >= img.get_width():
                continue
            img.set_pixel(xx, yy, c)

static func _fill_circle(img: Image, cx: int, cy: int, r: int, c: Color) -> void:
    var r2: int = r * r
    for yy in range(cy - r, cy + r + 1):
        if yy < 0 or yy >= img.get_height():
            continue
        for xx in range(cx - r, cx + r + 1):
            if xx < 0 or xx >= img.get_width():
                continue
            var dx: int = xx - cx
            var dy: int = yy - cy
            if dx * dx + dy * dy <= r2:
                img.set_pixel(xx, yy, c)

static func _outline(img: Image, col: Color) -> void:
    var w: int = img.get_width()
    var h: int = img.get_height()
    var out: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
    out.fill(Color(0, 0, 0, 0))
    for y in range(h):
        for x in range(w):
            var a: float = img.get_pixel(x, y).a
            if a <= 0.01:
                var touching: bool = false
                for oy in range(-1, 2):
                    for ox in range(-1, 2):
                        if ox == 0 and oy == 0:
                            continue
                        var nx: int = x + ox
                        var ny: int = y + oy
                        if nx < 0 or ny < 0 or nx >= w or ny >= h:
                            continue
                        if img.get_pixel(nx, ny).a > 0.01:
                            touching = true
                if touching:
                    out.set_pixel(x, y, col)
    # composite
    for y2 in range(h):
        for x2 in range(w):
            var p: Color = img.get_pixel(x2, y2)
            if p.a <= 0.01:
                img.set_pixel(x2, y2, out.get_pixel(x2, y2))

static func _scaled_texture(img: Image, scale: int) -> Texture2D:
    var s: int = max(1, scale)
    if s == 1:
        return ImageTexture.create_from_image(img)
    var w: int = img.get_width() * s
    var h: int = img.get_height() * s
    var out: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
    out.fill(Color(0, 0, 0, 0))
    for y in range(img.get_height()):
        for x in range(img.get_width()):
            var c: Color = img.get_pixel(x, y)
            var sx: int = x * s
            var sy: int = y * s
            for yy in range(sy, sy + s):
                for xx in range(sx, sx + s):
                    out.set_pixel(xx, yy, c)
    return ImageTexture.create_from_image(out)
