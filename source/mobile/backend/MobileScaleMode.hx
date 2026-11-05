/*
 * Copyright (C) 2025 Mobile Porting Team
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */

package mobile.backend;

import flixel.FlxCamera;
import flixel.math.FlxPoint;
import flixel.system.scaleModes.BaseScaleMode;

/**
 * Widescreen estilo V-Slice (sin estirar la imagen).
 *
 * - La imagen se escala de forma UNIFORME según la altura (720).
 * - Si la pantalla es más ancha que 16:9, las cámaras se agrandan hacia
 *   los lados y el contenido original (1280x720) queda centrado.
 * - `gameCutoutSize.x` = píxeles extra que hay a cada lado (en coords del juego).
 *
 * @author: Karim Akra (base) / modificado para NixerEngine
 */
class MobileScaleMode extends BaseScaleMode
{
	public static var allowWideScreen(default, set):Bool = true;

	/** Píxeles extra a cada lado del área 1280x720 (x = lados, y siempre 0). */
	public static var gameCutoutSize(default, null):FlxPoint = FlxPoint.get();

	static var hooked:Bool = false;

	public function new()
	{
		super();
		if (!hooked)
		{
			hooked = true;
			// Cualquier cámara nueva (camHUD, camOther, etc.) se ajusta sola.
			FlxG.cameras.cameraAdded.add(fitCamera);
		}
	}

	// Siempre activo (ignora la casilla de Opciones). Para volver a usar la
	// casilla, cambia el cuerpo por: ClientPrefs.data != null && ClientPrefs.data.wideScreen && allowWideScreen
	static inline function isWide():Bool
		return allowWideScreen;

	override function updateGameSize(Width:Int, Height:Int):Void
	{
		if (isWide())
		{
			// Ocupa toda la ventana; la escala uniforme se calcula en updateScaleOffset.
			gameSize.x = Width;
			gameSize.y = Height;
		}
		else
		{
			var ratio:Float = FlxG.width / FlxG.height;
			var realRatio:Float = Width / Height;

			if (realRatio < ratio)
			{
				gameSize.x = Width;
				gameSize.y = Math.floor(gameSize.x / ratio);
			}
			else
			{
				gameSize.y = Height;
				gameSize.x = Math.floor(gameSize.y * ratio);
			}
		}
	}

	override function updateScaleOffset():Void
	{
		if (isWide())
		{
			// Escala uniforme por altura (como V-Slice), sin deformar.
			scale.x = scale.y = gameSize.y / FlxG.height;
			offset.set(0, 0);
		}
		else
			super.updateScaleOffset();
	}

	override function updateGamePosition():Void
	{
		if (isWide())
			FlxG.game.x = FlxG.game.y = 0;
		else
			super.updateGamePosition();
	}

	override public function onMeasure(Width:Int, Height:Int):Void
	{
		super.onMeasure(Width, Height);

		if (isWide())
		{
			var wideWidth:Float = Width / scale.x;
			gameCutoutSize.set(Math.max(0, Math.ceil((wideWidth - FlxG.width) / 2)), 0);
		}
		else
			gameCutoutSize.set(0, 0);

		for (cam in FlxG.cameras.list)
			fitCamera(cam);

		lastCut = Std.int(gameCutoutSize.x);
	}

	static var lastCut:Int = 0;

	/**
	 * - Cámara principal (la primera): se agranda a los lados y su scroll se corre
	 *   para que el contenido 1280x720 quede centrado.
	 * - Cámaras secundarias (HUD, controles, etc.): NO se agrandan; se mueven hacia
	 *   el centro (cam.x = borde extra). Así notas, flechas y botones quedan siempre
	 *   alineados entre sí, sin importar su scrollFactor.
	 */
	static function fitCamera(cam:FlxCamera):Void
	{
		if (cam == null)
			return;

		var newCut:Int = Std.int(gameCutoutSize.x);

		if (FlxG.cameras.list.indexOf(cam) == 0)
		{
			var extra:Int = cam.width - FlxG.width;
			if (extra < 0 || extra % 2 != 0)
				return; // cámara con tamaño propio, no se toca

			var oldCut:Int = Std.int(extra / 2);
			if (oldCut == newCut)
				return;

			cam.width = FlxG.width + newCut * 2;
			cam.scroll.x -= (newCut - oldCut);
		}
		else
		{
			if (cam.width != FlxG.width)
				return; // cámara con tamaño propio, no se toca
			if (cam.x == 0 || Std.int(cam.x) == lastCut)
				cam.x = newCut;
		}
	}

	@:noCompletion
	private static function set_allowWideScreen(value:Bool):Bool
	{
		allowWideScreen = value;
		FlxG.scaleMode = new MobileScaleMode();
		return value;
	}
}
