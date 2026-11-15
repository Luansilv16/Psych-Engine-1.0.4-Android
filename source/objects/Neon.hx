package objects;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxGradient;
import flixel.util.FlxSpriteUtil;
import mobile.backend.MobileScaleMode;
import openfl.geom.Rectangle;

/**
 * Paleta y helpers del estilo neón/cyberpunk.
 * Úsalo desde cualquier menú: Neon.TEXT, Neon.panel(w, h), Neon.styleText(txt), etc.
 */
class Neon
{
	public static inline var MAGENTA:FlxColor = 0xFFFF2BD6;
	public static inline var CYAN:FlxColor    = 0xFF00F0FF;
	public static inline var BLUE:FlxColor    = 0xFF1E3BFF;
	public static inline var BG:FlxColor      = 0xFF07061A;
	public static inline var PANEL:FlxColor   = 0xCC0B0A24; // negro azulado semitransparente
	public static inline var TEXT:FlxColor    = 0xFFEAF8FF;
	public static inline var DIM:FlxColor     = 0xFF5A5C86;

	/** Ancho real de la pantalla en píxeles virtuales (1280 + bordes del widescreen). */
	public static inline function wideW():Int
		return Std.int(FlxG.width + MobileScaleMode.gameCutoutSize.x * 2);

	/** X donde empieza el borde izquierdo real de la pantalla. */
	public static inline function wideX():Float
		return -MobileScaleMode.gameCutoutSize.x;

	/** Panel redondeado con borde de neón. (0xFF00F0FF = cian) */
	public static function panel(w:Int, h:Int, border:Int = 0xFF00F0FF):FlxSprite
	{
		var spr = new FlxSprite();
		spr.makeGraphic(w, h, FlxColor.TRANSPARENT, true);
		FlxSpriteUtil.drawRoundRect(spr, 0, 0, w, h, 15, 15, PANEL);
		FlxSpriteUtil.drawRoundRect(spr, 1, 1, w - 2, h - 2, 14, 14, FlxColor.TRANSPARENT, {thickness: 2, color: border});
		return spr;
	}

	/** Texto con contorno de color neón. */
	public static function styleText(txt:FlxText, ?glow:FlxColor, size:Int = 24):FlxText
	{
		txt.setFormat(Paths.font("vcr.ttf"), size, TEXT, LEFT, FlxTextBorderStyle.OUTLINE, glow != null ? glow : CYAN);
		txt.borderSize = 2;
		return txt;
	}

	/** Degradado de fondo azul oscuro a violeta. */
	public static function gradient(w:Int, h:Int):FlxSprite
	{
		var cols:Array<FlxColor> = [BG, 0xFF14104A, 0xFF2A0F55];
		return FlxGradient.createGradientFlxSprite(w, h, cols, 1, 90);
	}

	/** Líneas de escaneo (una línea oscura cada 4 píxeles). */
	public static function scanlines(w:Int, h:Int, x:Float = 0):FlxSprite
	{
		var spr = new FlxSprite(x, 0).makeGraphic(w, h, FlxColor.TRANSPARENT, true);
		var r = new Rectangle(0, 0, w, 1);
		var y:Int = 0;
		while (y < h)
		{
			r.y = y;
			spr.pixels.fillRect(r, 0x33000000);
			y += 4;
		}
		spr.dirty = true;
		return spr;
	}

	/** Oscurece un color hacia el fondo neón (para tintar fondos de mods sin perder su identidad). */
	public static function darken(c:FlxColor, amount:Float = 0.55):FlxColor
		return FlxColor.interpolate(c, BG, amount);

	/** Colores alternados para listas (magenta / cian). */
	public static function accentFor(index:Int):FlxColor
		return index % 2 == 0 ? MAGENTA : CYAN;
}
