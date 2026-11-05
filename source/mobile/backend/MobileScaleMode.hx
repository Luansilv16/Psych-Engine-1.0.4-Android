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
import openfl.events.Event;

/**
 * Widescreen estilo V-Slice (sin estirar la imagen), adaptado a cualquier celular.
 *
 * - Se escala de forma UNIFORME (la imagen nunca se deforma).
 * - Pantalla más ancha que 16:9 (la mayoría de celulares): se rellena todo el ancho
 *   y el contenido 1280x720 queda centrado. `gameCutoutSize.x` = píxeles extra a cada lado.
 * - Pantalla más cuadrada que 16:9 (tablets): el juego se ajusta al ancho y quedan
 *   franjas negras arriba y abajo.
 * - Si el jugador desactiva "Modo Pantalla Ancha" en Opciones, vuelve el modo clásico
 *   con bordes negros. El cambio se aplica al momento.
 */
class MobileScaleMode extends BaseScaleMode
{
	public static var allowWideScreen(default, set):Bool = true;

	/** Píxeles extra a cada lado del área 1280x720 (x = lados, y siempre 0). */
	public static var gameCutoutSize(default, null):FlxPoint = FlxPoint.get();

	static var hooked:Bool = false;
	static var lastWide:Bool = false;
	static var lastCut:Int = 0;
	static var fullCams:Array<FlxCamera> = [];

	/**
	 * Marca una cámara como "de ancho completo" (x = 0, tan ancha como la pantalla real).
	 * Se usa para los controles táctiles: así los botones y el hitbox llegan a los bordes.
	 */
	public static function makeFullWidth(cam:FlxCamera):Void
	{
		if (cam == null)
			return;
		if (!fullCams.contains(cam))
			fullCams.push(cam);
		fitCamera(cam);
	}

	public function new()
	{
		super();
		if (!hooked)
		{
			hooked = true;
			// Cualquier cámara nueva (camHUD, camOther, etc.) se ajusta sola.
			FlxG.cameras.cameraAdded.add(fitCamera);
			// Si el jugador cambia la opción, se re-mide la pantalla al momento.
			FlxG.signals.postUpdate.add(checkPref);
		}
	}

	static inline function isWide():Bool
		return ClientPrefs.data != null && ClientPrefs.data.wideScreen && allowWideScreen;

	static function checkPref():Void
	{
		var wide:Bool = isWide();
		if (wide == lastWide)
			return;
		lastWide = wide;
		// Dispara el mismo evento que un cambio de tamaño de ventana
		FlxG.stage.dispatchEvent(new Event(Event.RESIZE));
	}

	override function updateGameSize(Width:Int, Height:Int):Void
	{
		if (isWide())
		{
			var s:Float = Math.min(Width / FlxG.width, Height / FlxG.height);
			gameSize.x = Width;
			gameSize.y = Math.floor(FlxG.height * s);
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
			// Escala uniforme: nunca se deforma
			scale.x = scale.y = Math.min(deviceSize.x / FlxG.width, deviceSize.y / FlxG.height);
			offset.x = 0;
			offset.y = Math.ceil((deviceSize.y - FlxG.height * scale.y) / 2);
		}
		else
			super.updateScaleOffset();
	}

	override function updateGamePosition():Void
	{
		if (isWide())
		{
			FlxG.game.x = offset.x;
			FlxG.game.y = offset.y;
		}
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

		lastWide = isWide();

		fullCams = fullCams.filter(function(c:FlxCamera) return FlxG.cameras.list.contains(c));

		for (cam in FlxG.cameras.list)
			fitCamera(cam);

		lastCut = Std.int(gameCutoutSize.x);
	}

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

		if (fullCams.contains(cam))
		{
			cam.x = 0;
			cam.width = FlxG.width + newCut * 2;
			return;
		}

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
			// Cámara nueva (x=0, ancho normal) o ya ajustada antes por nosotros
			var fresh:Bool = (cam.width == FlxG.width && cam.x == 0);
			var fitted:Bool = (cam.width == FlxG.width + lastCut && Std.int(cam.x) == lastCut);
			if (!fresh && !fitted)
				return; // cámara con tamaño propio, no se toca

			// Se mueve al centro y se extiende hacia la derecha, así no se recorta nada
			cam.x = newCut;
			cam.width = FlxG.width + newCut;
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
