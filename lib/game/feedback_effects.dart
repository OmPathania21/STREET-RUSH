import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';

class CoinPickupEffect extends SpriteComponent {
  CoinPickupEffect({
    required Sprite sprite,
    required Vector2 worldPosition,
    required Vector2 effectSize,
  }) : super(
          sprite: sprite,
          position: worldPosition,
          size: effectSize,
          anchor: Anchor.center,
          priority: 300,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    add(
      ScaleEffect.to(
        Vector2.all(1.35),
        EffectController(
          duration: 0.09,
          curve: Curves.easeOut,
        ),
      ),
    );

    add(
      OpacityEffect.to(
        0,
        EffectController(
          duration: 0.22,
          startDelay: 0.05,
          curve: Curves.easeIn,
        ),
        onComplete: removeFromParent,
      ),
    );
  }
}

class CrashFlashEffect extends RectangleComponent {
  CrashFlashEffect({
    required Vector2 viewportSize,
  }) : super(
          position: Vector2.zero(),
          size: viewportSize,
          priority: 700,
          paint: Paint()..color = const Color(0x99FF5252),
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(
      OpacityEffect.to(
        0,
        EffectController(
          duration: 0.34,
          curve: Curves.easeOut,
        ),
        onComplete: removeFromParent,
      ),
    );
  }
}