import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'street_rush_game.dart';

class EnemyCar extends SpriteComponent
    with CollisionCallbacks, HasGameReference<StreetRushGame> {
  EnemyCar({
    required Sprite sprite,
    required Vector2 spawnPosition,
    required Vector2 carSize,
    required this.speed,
  }) : super(
          sprite: sprite,
          position: spawnPosition,
          size: carSize,
          anchor: Anchor.center,
          priority: 5,
        );

  double speed;

  static Vector2 sizeForScreen(Vector2 screenSize) {
    final double width = (screenSize.x * 0.18).clamp(52.0, 94.0).toDouble();
    return Vector2(width, width * 1.75);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox());
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