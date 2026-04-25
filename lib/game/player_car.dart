import 'dart:math' as math;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';

import 'coin.dart';
import 'enemy_car.dart';

class PlayerCar extends SpriteComponent with CollisionCallbacks {
  PlayerCar({
    required Sprite sprite,
    required this.onHitEnemy,
    required this.onCollectCoin,
  })
      : super(
          sprite: sprite,
          anchor: Anchor.center,
          priority: 10,
        );

  final VoidCallback onHitEnemy;
  final ValueChanged<Coin> onCollectCoin;

  double _targetX = 0;
  double _velocityX = 0;
  double _minX = 0;
  double _maxX = 0;
  double _maxSpeed = 0;
  double _acceleration = 0;
  double _deceleration = 0;
  double _handlingMultiplier = 1;
  double _coinMagnetRadiusMultiplier = 1;
  double _lastScreenWidth = 0;
  bool _isConfigured = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox());
  }

  void onScreenResize(
    Vector2 screenSize, {
    bool keepHorizontalProgress = true,
  }) {
    final double previousRange = (_maxX - _minX).abs() < 0.001
        ? 1
        : (_maxX - _minX);
    final double previousProgress = (_isConfigured && keepHorizontalProgress)
        ? ((position.x - _minX) / previousRange).clamp(0.0, 1.0).toDouble()
        : 0.5;

    final double width = (screenSize.x * 0.18).clamp(52.0, 94.0).toDouble();
    final double height = width * 1.75;
    size = Vector2(width, height);
    _lastScreenWidth = screenSize.x;

    _minX = size.x / 2;
    _maxX = screenSize.x - size.x / 2;

    final double laneBottomPadding =
        (screenSize.y * 0.09).clamp(26.0, 96.0).toDouble();
    final double stableX = _minX + (_maxX - _minX) * previousProgress;
    position = Vector2(
      _clampX(stableX),
      screenSize.y - laneBottomPadding - (size.y / 2),
    );

    _targetX = _isConfigured ? _clampX(_targetX) : position.x;
    _recomputeMovementParams();
    _isConfigured = true;
  }

  void applyUpgradeModifiers({
    required double handlingMultiplier,
    required double coinMagnetRadiusMultiplier,
  }) {
    _handlingMultiplier = handlingMultiplier < 1 ? 1 : handlingMultiplier;
    _coinMagnetRadiusMultiplier =
        coinMagnetRadiusMultiplier < 1 ? 1 : coinMagnetRadiusMultiplier;
    if (_isConfigured) {
      _recomputeMovementParams();
    }
  }

  double get coinMagnetRadius {
    if (!_isConfigured) {
      return 0;
    }
    return (size.x * 0.85) * _coinMagnetRadiusMultiplier;
  }

  void resetForNewRun(Vector2 screenSize) {
    onScreenResize(screenSize, keepHorizontalProgress: false);
    _velocityX = 0;
    _targetX = position.x;
  }

  void setTargetX(double canvasX) {
    if (!_isConfigured) {
      _targetX = canvasX;
      return;
    }
    _targetX = _clampX(canvasX);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!_isConfigured) {
      return;
    }

    // Clamp dt to keep movement stable after app pauses/resumes.
    final double frameDt = math.min(dt, 1 / 30);
    final double distance = _targetX - position.x;

    if (distance.abs() < 0.2 && _velocityX.abs() < 2) {
      position.x = _targetX;
      _velocityX = 0;
      return;
    }

    final double slowDownDistance = size.x * 1.6;
    final double speedScale =
        (distance.abs() / slowDownDistance).clamp(0.2, 1.0).toDouble();
    final double desiredVelocity = distance.sign * (_maxSpeed * speedScale);

    final double appliedAccel =
        (_velocityX.sign == desiredVelocity.sign || _velocityX == 0)
            ? _acceleration
            : _deceleration;
    _velocityX =
        _moveToward(_velocityX, desiredVelocity, appliedAccel * frameDt);

    double nextX = position.x + (_velocityX * frameDt);
    if ((distance > 0 && nextX > _targetX) ||
        (distance < 0 && nextX < _targetX)) {
      nextX = _targetX;
      _velocityX = 0;
    }

    position.x = _clampX(nextX);

    if (position.x <= _minX || position.x >= _maxX) {
      _velocityX = 0;
    }
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is EnemyCar) {
      onHitEnemy();
      return;
    }
    if (other is Coin) {
      onCollectCoin(other);
    }
  }

  double _clampX(double rawX) => rawX.clamp(_minX, _maxX).toDouble();

  void _recomputeMovementParams() {
    _maxSpeed = _lastScreenWidth * 2.4 * _handlingMultiplier;
    _acceleration = _lastScreenWidth * 12.0 * _handlingMultiplier;
    _deceleration = _lastScreenWidth * 15.0 * _handlingMultiplier;
  }

  double _moveToward(double current, double target, double maxDelta) {
    if ((target - current).abs() <= maxDelta) {
      return target;
    }
    return current + ((target > current) ? maxDelta : -maxDelta);
  }
}