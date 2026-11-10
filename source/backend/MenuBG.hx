package backend;

import openfl.utils.AssetType;
import mobile.backend.MobileScaleMode;

/**
 * Fondo compartido de Freeplay, Logros y Créditos (assets/shared/images/freeplay/bg.png).
 * Es un PNG blanco/gris que cada menú pinta con `sprite.color`.
 *
 * Busca el archivo con varios nombres y, si no lo encuentra, usa el fondo de siempre
 * y muestra un aviso rojo en pantalla para que se note (se apaga con SHOW_WARNING = false).
 */
class MenuBG
{
	public static inline final SHOW_WARNING:Bool = true;

	// Nombres probados en orden (Android distingue mayúsculas de minúsculas)
	static final CANDIDATES:Array<String> = ['freeplay/bg', 'freeplay/BG', 'freeplay/Bg', 'freeplay/background', 'freeplay/bg_gray', 'freeplay/bg_grey'];

	public static var lastFound:Bool = false;
	public static var lastName:String = '';

	/** Crea el sprite de fondo ya escalado para cubrir toda la pantalla (incluye pantalla ancha). */
	public static function create(fallback:String = 'menuDesat'):FlxSprite
	{
		var key:String = null;
		for (c in CANDIDATES)
		{
			if (Paths.fileExists('images/$c.png', AssetType.IMAGE))
			{
				key = c;
				break;
			}
		}
		lastFound = (key != null);
		lastName = lastFound ? key : fallback;

		var W:Float = FlxG.width + MobileScaleMode.gameCutoutSize.x * 2;
		var H:Float = FlxG.height;

		var spr:FlxSprite = new FlxSprite().loadGraphic(Paths.image(lastName));
		spr.antialiasing = ClientPrefs.data.antialiasing;
		var sc:Float = Math.max(W / spr.width, H / spr.height);
		spr.setGraphicSize(Std.int(spr.width * sc));
		spr.updateHitbox();
		spr.setPosition((W - spr.width) / 2, (H - spr.height) / 2);
		spr.scrollFactor.set();
		return spr;
	}

	/** Texto rojo de aviso si no se encontró bg.png (o null si todo está bien). Añádelo al final de create(). */
	public static function warning():FlxText
	{
		if (!SHOW_WARNING || lastFound) return null;
		var t:FlxText = new FlxText(8, FlxG.height - 64, FlxG.width - 16,
			'BG NOT FOUND: images/freeplay/bg.png (using ' + lastName + ')', 16);
		t.setFormat(Paths.font('vcr.ttf'), 16, 0xFFFF5555, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		t.scrollFactor.set();
		return t;
	}

	/** Sube el brillo de colores muy oscuros para que el fondo pintado no quede negro. */
	public static function lift(c:FlxColor, minBrightness:Float = 0.5):FlxColor
	{
		if (c.brightness >= minBrightness) return c;
		var out:FlxColor = c;
		out.brightness = minBrightness;
		return out;
	}
}
