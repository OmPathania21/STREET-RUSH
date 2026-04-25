import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'street_rush_game.dart';

class Coin extends SpriteComponent
    with CollisionCallbacks, HasGameReference<StreetRushGame> {
  Coin({
    required Sprite sprite,
    required Vector2 spawnPosition,
    required Vector2 coinSize,
    required this.speed,
  }) : super(
          sprite: sprite,
          position: spawnPosition,
          size: coinSize,
          anchor: Anchor.center,
          priority: 6,
        );

  double speed;

  static Vector2 sizeForScreen(Vector2 screenSize) {
    final double diameter = (screenSize.x * 0.1).clamp(24.0, 38.0).toDouble();
    return Vector2.all(diameter);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(CircleHitbox());
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.y += speed * dt;

    if (position.y - (size.y / 2) > game.size.y) {
      removeFromParent();
    }
  }
}