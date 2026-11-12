package objects;

class HealthIcon extends FlxSprite
{
	public var sprTracker:FlxSprite;
	private var isPlayer:Bool = false;
	private var char:String = '';
	private var isFreeplayCustomIcon:Bool = false;

	public function new(char:String = 'face', isPlayer:Bool = false, ?allowGPU:Bool = true)
	{
		super();
		this.isPlayer = isPlayer;
		changeIcon(char, allowGPU);
		scrollFactor.set();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (sprTracker != null)
			setPosition(sprTracker.x + sprTracker.width + 12, sprTracker.y - 30);
	}

	private var iconOffsets:Array<Float> = [0, 0];
	public function changeIcon(char:String, ?allowGPU:Bool = true) {
		if(this.char != char) {
			var name:String = 'icons/' + char;
			var freeplayName:String = 'freeplay/icon/' + char;
			isFreeplayCustomIcon = Paths.fileExists('images/' + freeplayName + '.png', IMAGE);

			// Los iconos personalizados de Freeplay tienen prioridad.
			if (isFreeplayCustomIcon)
				name = freeplayName;
			else if(!Paths.fileExists('images/' + name + '.png', IMAGE))
				name = 'icons/icon-' + char; //Older versions of psych engine's support
			if(!Paths.fileExists('images/' + name + '.png', IMAGE))
			{
				name = 'icons/icon-face'; //Prevents crash from missing icon
				isFreeplayCustomIcon = false;
			}

			var graphic = Paths.image(name, allowGPU);
			var iSize:Float = Math.round(graphic.width / graphic.height);
			loadGraphic(graphic, true, Math.floor(graphic.width / iSize), Math.floor(graphic.height));
			iconOffsets[0] = (width - 150) / iSize;
			iconOffsets[1] = (height - 150) / iSize;
			updateHitbox();

			animation.add(char, [for(i in 0...frames.frames.length) i], 0, false, isPlayer);
			animation.play(char);
			this.char = char;

			if(char.endsWith('-pixel'))
				antialiasing = false;
			else
				antialiasing = ClientPrefs.data.antialiasing;
		}
	}

	public var autoAdjustOffset:Bool = true;
	override function updateHitbox()
	{
		super.updateHitbox();
		if(autoAdjustOffset)
		{
			offset.x = iconOffsets[0];
			offset.y = iconOffsets[1];
		}
	}


	// Freeplay: frame 0 = normal y frame 1 = feliz en iconos personalizados.
	public function setFreeplaySelected(selected:Bool):Void
	{
		if (!isFreeplayCustomIcon || frames == null || frames.frames == null || frames.frames.length == 0)
			return;

		if (ClientPrefs.data.freeplayIconAnimation && frames.frames.length > 1)
		{
			if (animation.getByName('freeplayLoop') == null)
				animation.add('freeplayLoop', [for (i in 0...frames.frames.length) i], 10, true);
			animation.play('freeplayLoop', true);
		}
		else
		{
			animation.stop();
			animation.frameIndex = (selected && frames.frames.length > 1) ? 1 : 0;
		}
	}

	public function getCharacter():String {
		return char;
	}
}
