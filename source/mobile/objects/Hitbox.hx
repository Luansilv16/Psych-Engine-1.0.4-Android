private function createHint(X:Float, Y:Float, Width:Int, Height:Int, Color:Int = 0xFFFFFF):TouchButton
{
    var hint = new TouchButton(X, Y);
    hint.statusAlphas = [];
    hint.statusIndicatorType = NONE;
    hint.loadGraphic(createHintGraphic(Width, Height));

    hint.label = new FlxSprite();
    hint.labelStatusDiff = (ClientPrefs.data.hitboxType != "Hidden") ? ClientPrefs.data.controlsAlpha : 0.00001;
    hint.label.loadGraphic(createHintGraphic(Width, Math.floor(Height * 0.035), true));
    if (ClientPrefs.data.hitboxPos)
        hint.label.offset.y -= (hint.height - hint.label.height) / 2;
    else
        hint.label.offset.y += (hint.height - hint.label.height) / 2;

    if (ClientPrefs.data.hitboxType != "Hidden")
    {
        var hintTween:FlxTween = null;
        var hintLaneTween:FlxTween = null;

        hint.onDown.callback = function()
        {
            onButtonDown.dispatch(hint);
            if (hintTween != null) hintTween.cancel();
            if (hintLaneTween != null) hintLaneTween.cancel();
            hintTween = FlxTween.tween(hint, {alpha: ClientPrefs.data.controlsAlpha}, ClientPrefs.data.controlsAlpha / 100, {
                ease: FlxEase.circInOut,
                onComplete: (twn:FlxTween) -> hintTween = null
            });
            hintLaneTween = FlxTween.tween(hint.label, {alpha: 0.00001}, ClientPrefs.data.controlsAlpha / 10, {
                ease: FlxEase.circInOut,
                onComplete: (twn:FlxTween) -> hintTween = null
            });
        }

        hint.onOut.callback = hint.onUp.callback = function()
        {
            onButtonUp.dispatch(hint);
            if (hintTween != null) hintTween.cancel();
            if (hintLaneTween != null) hintLaneTween.cancel();
            hintTween = FlxTween.tween(hint, {alpha: 0.00001}, ClientPrefs.data.controlsAlpha / 10, {
                ease: FlxEase.circInOut,
                onComplete: (twn:FlxTween) -> hintTween = null
            });
            hintLaneTween = FlxTween.tween(hint.label, {alpha: ClientPrefs.data.controlsAlpha}, ClientPrefs.data.controlsAlpha / 100, {
                ease: FlxEase.circInOut,
                onComplete: (twn:FlxTween) -> hintTween = null
            });
        }
    }
    else
    {
        hint.onDown.callback = () -> onButtonDown.dispatch(hint);
        hint.onOut.callback = hint.onUp.callback = () -> onButtonUp.dispatch(hint);
    }

    hint.immovable = hint.multiTouch = true;
    hint.solid = hint.moves = false;
    hint.alpha = 0.00001;
    hint.label.alpha = (ClientPrefs.data.hitboxType != "Hidden") ? ClientPrefs.data.controlsAlpha : 0.00001;
    hint.canChangeLabelAlpha = false;
    hint.label.antialiasing = hint.antialiasing = ClientPrefs.data.antialiasing;
    hint.color = Color;
    hint.visible = false; // ← التعديل: إخفاء الصناديق تماماً مع بقائها قابلة للمس
    #if FLX_DEBUG
    hint.ignoreDrawDebug = true;
    #end
    return hint;
}