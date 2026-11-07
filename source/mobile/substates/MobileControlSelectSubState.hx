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

package mobile.substates;

import flixel.FlxObject;
import flixel.addons.display.FlxBackdrop;
import flixel.addons.display.FlxGridOverlay;
import flixel.util.FlxGradient;
import mobile.backend.TouchUtil;
import flixel.input.touch.FlxTouch;
import flixel.ui.FlxButton as UIButton;

class MobileControlSelectSubState extends MusicBeatSubstate
{
	// Solo Hitbox — se eliminaron Pad-Right, Pad-Left, Pad-Custom y Pad-Extra
	var options:Array<String> = ['Hitbox'];
	var control:MobileControls;
	var leftArrow:FlxSprite;
	var rightArrow:FlxSprite;
	var itemText:Alphabet;
	var positionText:FlxText;
	var positionTextBg:FlxSprite;
	var bg:FlxBackdrop;
	var ui:FlxCamera;
	var curOption:Int = 0; // siempre Hitbox
	var buttonBinded:Bool = false;
	var bindButton:TouchButton;
	var reset:UIButton;
	var tweenieShit:Float = 0;

	public function new()
	{
		super();

		// Forzar modo Hitbox
		MobileData.forcedMode = 3;

		bg = new FlxBackdrop(FlxGridOverlay.createGrid(80, 80, 160, 160, true,
			FlxColor.fromRGB(FlxG.random.int(0, 255), FlxG.random.int(0, 255), FlxG.random.int(0, 255)),
			FlxColor.fromRGB(FlxG.random.int(0, 255), FlxG.random.int(0, 255), FlxG.random.int(0, 255))));
		bg.velocity.set(40, 40);
		bg.alpha = 0;
		bg.antialiasing = ClientPrefs.data.antialiasing;
		FlxTween.tween(bg, {alpha: 0.45}, 0.3, {
			ease: FlxEase.quadOut,
			onComplete: (twn:FlxTween) ->
			{
				FlxTween.tween(ui, {alpha: 1}, 0.2, {ease: FlxEase.circOut});
			}
		});
		add(bg);

		FlxG.mouse.visible = !FlxG.onMobile;

		ui = new FlxCamera();
		ui.bgColor.alpha = 0;
		ui.alpha = 0;
		FlxG.cameras.add(ui, false);

		itemText = new Alphabet(0, 60, '');
		itemText.alignment = LEFT;
		itemText.cameras = [ui];
		add(itemText);

		leftArrow = new FlxSprite(0, itemText.y - 25);
		leftArrow.frames = Paths.getSparrowAtlas('campaign_menu_UI_assets');
		leftArrow.animation.addByPrefix('idle', 'arrow left');
		leftArrow.animation.addByPrefix('press', "arrow push left");
		leftArrow.animation.play('idle');
		leftArrow.cameras = [ui];
		leftArrow.visible = false; // no hay más opciones, no se necesitan flechas
		add(leftArrow);

		itemText.x = 70;
		leftArrow.x = itemText.x - 60;

		rightArrow = new FlxSprite().loadGraphicFromSprite(leftArrow);
		rightArrow.flipX = true;
		rightArrow.setPosition(itemText.x + itemText.width + 10, itemText.y - 25);
		rightArrow.cameras = [ui];
		rightArrow.visible = false;
		add(rightArrow);

		positionText = new FlxText(0, FlxG.height, FlxG.width / 4, '');
		positionText.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.WHITE, FlxTextAlign.LEFT);
		positionText.visible = false;

		positionTextBg = FlxGradient.createGradientFlxSprite(250, 150, [FlxColor.BLACK, FlxColor.BLACK, FlxColor.BLACK, FlxColor.TRANSPARENT], 1, 360);
		positionTextBg.setPosition(0, FlxG.height - positionTextBg.height);
		positionTextBg.visible = false;
		positionTextBg.alpha = 0.8;
		add(positionTextBg);
		positionText.cameras = [ui];
		add(positionText);

		var exit = new UIButton(0, itemText.y - 25, Language.getPhrase('mobileC_exitandsave', "Exit & Save"), () ->
		{
			MobileData.mode = 3; // forzar Hitbox
			controls.isInSubstate = FlxG.mouse.visible = false;
			FlxG.sound.play(Paths.sound('cancelMenu'));
			MobileData.forcedMode = null;
			close();
		});
		exit.color = FlxColor.LIME;
		exit.setGraphicSize(Std.int(exit.width) * 3);
		exit.updateHitbox();
		exit.x = FlxG.width - exit.width - 70;
		exit.label.setFormat(Paths.font('vcr.ttf'), 28, FlxColor.WHITE, FlxTextAlign.CENTER);
		exit.label.fieldWidth = exit.width;
		exit.label.x = ((exit.width - exit.label.width) / 2) + exit.x;
		exit.label.offset.y = -10;
		exit.cameras = [ui];
		add(exit);

		reset = new UIButton(exit.x, exit.height + exit.y + 20, Language.getPhrase('mobileC_reset', "Reset"), () ->
		{
			changeOption(0);
			FlxG.sound.play(Paths.sound('cancelMenu'));
		});
		reset.color = FlxColor.RED;
		reset.setGraphicSize(Std.int(reset.width) * 3);
		reset.updateHitbox();
		reset.label.setFormat(Paths.font('vcr.ttf'), 28, FlxColor.WHITE, FlxTextAlign.CENTER);
		reset.label.fieldWidth = reset.width;
		reset.label.x = ((reset.width - reset.label.width) / 2) + reset.x;
		reset.label.offset.y = -10;
		reset.cameras = [ui];
		reset.visible = false; // no hace falta en solo Hitbox
		add(reset);

		changeOption(0);
	}

	override function update(elapsed:Float)
	{
		// Ya no hay flechas ni cambio de opción
		tweenieShit += 180 * elapsed;
		super.update(elapsed);
	}

	function changeControls(?type:Int, ?extraMode:Bool = false)
	{
		if (type == null)
			type = 3; // siempre Hitbox
		if (control != null)
			control.destroy();
		if (members.contains(control))
			remove(control);
		control = new MobileControls(3, false); // modo 3 = Hitbox, sin extras
		add(control);
		control.cameras = [ui];
	}

	function changeOption(change:Int)
	{
		curOption = 0; // siempre Hitbox
		changeControls(3, false);
		updatePosText();
		setOptionText();
	}

	function setOptionText()
	{
		itemText.text = "Hitbox";
		itemText.updateHitbox();
		itemText.offset.set(0, 15);
	}

	function updatePosText()
	{
		positionText.visible = positionTextBg.visible = false;
	}

	function checkArrowButton(button:FlxSprite, func:Void->Void)
	{
		// desactivado
	}

	function moveButton(touch:FlxTouch, button:TouchButton):Void
	{
		// no se usa en Hitbox
	}
}
