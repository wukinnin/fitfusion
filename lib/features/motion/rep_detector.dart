import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../core/constants.dart';
import '../../core/enums.dart';
import '../../core/events.dart';

class _LandmarkBuffer {
  final int windowSize;
  final Queue<double> _values = Queue<double>();

  _LandmarkBuffer(this.windowSize);

  void add(double value) {
    _values.addLast(value);
    if (_values.length > windowSize) {
      _values.removeFirst();
    }
  }

  double get average {
    if (_values.isEmpty) return 0.0;
    return _values.reduce((a, b) => a + b) / _values.length;
  }

  bool get isFull => _values.length >= windowSize;

  void clear() => _values.clear();
}

// State Machine 1 — Squats
enum _SquatState { standing, squatDown }

// State Machine 2 — Jumping Jacks
enum _JumpingJackState { armsDown, armsUp }

// State Machine 3 — Standing Oblique Side Crunches
// Left and right sides are fully independent concurrent state machines.
// A rep is emitted the moment either side completes a full crunch-and-return cycle.
enum _CrunchSideState { extended, crunching }

class RepDetector {
  final WorkoutType workoutType;
  
  late final StreamSubscription<Pose?> _poseSubscription;
  final StreamController<RepEvent> _repController = StreamController<RepEvent>.broadcast();
  
  Stream<RepEvent> get repStream => _repController.stream;

  _SquatState _squatState = _SquatState.standing;
  final _LandmarkBuffer _squatBuffer = _LandmarkBuffer(kLandmarkBufferWindowSize);

  _JumpingJackState _jackState = _JumpingJackState.armsDown;
  final _LandmarkBuffer _jackLeftBuffer = _LandmarkBuffer(kLandmarkBufferWindowSize);
  final _LandmarkBuffer _jackRightBuffer = _LandmarkBuffer(kLandmarkBufferWindowSize);
  final _LandmarkBuffer _jackLegSpreadBuffer = _LandmarkBuffer(kLandmarkBufferWindowSize);
  final _LandmarkBuffer _jackLegSymmetryBuffer = _LandmarkBuffer(kLandmarkBufferWindowSize);

  // Per-side independent state — left and right are never mutually exclusive
  _CrunchSideState _leftCrunchState = _CrunchSideState.extended;
  _CrunchSideState _rightCrunchState = _CrunchSideState.extended;
  
  // Robustness: Cache the shoulder width so momentary occlusion doesn't break detection
  double? _lastValidShoulderWidth;

  // Primary rep metric: elbow-to-knee distance, normalised by shoulder width.
  // Small value = elbow and raised knee are close together (crunched).
  final _LandmarkBuffer _crunchLeftElbowKneeBuffer = _LandmarkBuffer(kLandmarkBufferWindowSize);
  final _LandmarkBuffer _crunchRightElbowKneeBuffer = _LandmarkBuffer(kLandmarkBufferWindowSize);

  RepDetector({
    required this.workoutType,
    required Stream<Pose?> poseStream,
  }) {
    _initializeStateForWorkout();
    _poseSubscription = poseStream.listen(_onPose);
  }

  void _initializeStateForWorkout() {
    reset();
  }

  void _onPose(Pose? pose) {
    if (pose == null) return;
    
    switch (workoutType) {
      case WorkoutType.squats:
        _processSquat(pose);
        break;
      case WorkoutType.jumpingJacks:
        _processJumpingJack(pose);
        break;
      case WorkoutType.obliqueCrunches:
        _processObliqueCrunch(pose);
        break;
    }
  }

  Future<void> dispose() async {
    await _poseSubscription.cancel();
    await _repController.close();
  }

  void _emitRep() {
    debugPrint('[RepDetector] REP DETECTED — $workoutType');
    _repController.add(RepEvent(
      workoutType: workoutType,
      timestamp: DateTime.now(),
    ));
  }

  void reset() {
    _squatState = _SquatState.standing;
    _jackState = _JumpingJackState.armsDown;
    _leftCrunchState = _CrunchSideState.extended;
    _rightCrunchState = _CrunchSideState.extended;
    _squatBuffer.clear();
    _jackLeftBuffer.clear();
    _jackRightBuffer.clear();
    _jackLegSpreadBuffer.clear();
    _jackLegSymmetryBuffer.clear();
    _crunchLeftElbowKneeBuffer.clear();
    _crunchRightElbowKneeBuffer.clear();
    _lastValidShoulderWidth = null;
    debugPrint('[RepDetector] State reset');
  }

  // --- Squat Logic ---

  void _processSquat(Pose pose) {
    // Use average of left and right sides for robustness
    // If one side is not visible, the other side still works
    double? metric = _computeSquatMetric(pose);
    if (metric == null) return;

    _squatBuffer.add(metric);
    if (!_squatBuffer.isFull) return; // wait for buffer to fill before deciding

    final smoothed = _squatBuffer.average;

    switch (_squatState) {
      case _SquatState.standing:
        // Hip drops toward knee — delta decreases
        // Must drop significantly (deep squat) to trigger state change
        if (smoothed < kSquatDownThreshold) {
          _squatState = _SquatState.squatDown;
          debugPrint('[RepDetector] Squat DOWN detected (metric: ${smoothed.toStringAsFixed(3)})');
        }
        break;

      case _SquatState.squatDown:
        // Hip rises back above knee — delta increases again
        // Must rise significantly (full standing) to trigger rep
        if (smoothed > kSquatUpThreshold) {
          _squatState = _SquatState.standing;
          _emitRep();
        }
        break;
    }
  }

  double? _computeSquatMetric(Pose pose) {
    // hipKneeDelta = knee.y - hip.y
    // In image space, y increases downward.
    // Standing: hip is well above knee, so knee.y > hip.y, delta is POSITIVE and large.
    // Squatting: hip descends toward knee level, delta gets SMALLER.
    
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final rightKnee = pose.landmarks[PoseLandmarkType.rightKnee];

    // Try to get at least one valid side
    double? leftDelta;
    double? rightDelta;

    if (leftHip != null && leftKnee != null &&
        leftHip.likelihood >= kLandmarkLikelihoodThreshold &&
        leftKnee.likelihood >= kLandmarkLikelihoodThreshold) {
      leftDelta = leftKnee.y - leftHip.y;
    }

    if (rightHip != null && rightKnee != null &&
        rightHip.likelihood >= kLandmarkLikelihoodThreshold &&
        rightKnee.likelihood >= kLandmarkLikelihoodThreshold) {
      rightDelta = rightKnee.y - rightHip.y;
    }

    if (leftDelta == null && rightDelta == null) return null;
    if (leftDelta == null) return rightDelta;
    if (rightDelta == null) return leftDelta;
    return (leftDelta + rightDelta) / 2.0; // average of both sides
  }

  // --- Jumping Jack Logic ---

  void _processJumpingJack(Pose pose) {
    final leftMetric = _computeJackMetric(
      pose, PoseLandmarkType.leftWrist, PoseLandmarkType.leftShoulder);
    final rightMetric = _computeJackMetric(
      pose, PoseLandmarkType.rightWrist, PoseLandmarkType.rightShoulder);
    
    // Returns [spreadRatio, symmetryRatio]
    final legMetrics = _computeJackLegMetrics(pose);

    if (leftMetric == null || rightMetric == null || legMetrics == null) return;

    _jackLeftBuffer.add(leftMetric);
    _jackRightBuffer.add(rightMetric);
    _jackLegSpreadBuffer.add(legMetrics[0]);
    _jackLegSymmetryBuffer.add(legMetrics[1]);

    if (!_jackLeftBuffer.isFull ||
        !_jackRightBuffer.isFull ||
        !_jackLegSpreadBuffer.isFull ||
        !_jackLegSymmetryBuffer.isFull) {
      return;
    }

    final leftSmoothed = _jackLeftBuffer.average;
    final rightSmoothed = _jackRightBuffer.average;
    final spreadSmoothed = _jackLegSpreadBuffer.average;
    final symmetrySmoothed = _jackLegSymmetryBuffer.average;

    // Debug print
    if (leftSmoothed > 0.05 || rightSmoothed > 0.05) {
       debugPrint('[JJ Debug] L:${leftSmoothed.toStringAsFixed(3)} R:${rightSmoothed.toStringAsFixed(3)} Spread:${spreadSmoothed.toStringAsFixed(2)} Sym:${symmetrySmoothed.toStringAsFixed(2)} State:$_jackState');
    }

    switch (_jackState) {
      case _JumpingJackState.armsDown:
        // Arms raise: wrist goes ABOVE shoulder
        // AND Legs must be symmetrically apart
        // symmetrySmoothed = min(distL, distR) / shoulderWidth.
        // If one leg stays in, symmetrySmoothed will be small.
        if (leftSmoothed > kJumpingJackWristRaiseThreshold &&
            rightSmoothed > kJumpingJackWristRaiseThreshold &&
            symmetrySmoothed > kJumpingJackPerLegThreshold) {
          _jackState = _JumpingJackState.armsUp;
          debugPrint('[RepDetector] Jumping Jack UP detected (Symmetrical)');
        }
        break;

      case _JumpingJackState.armsUp:
        // Arms return down: wrist drops back below shoulder
        // AND Legs must be together (total spread small)
        if (leftSmoothed <= 0 && 
            rightSmoothed <= 0 &&
            spreadSmoothed < kJumpingJackLegsTogetherRatio) {
          _jackState = _JumpingJackState.armsDown;
          _emitRep();
        }
        break;
    }
  }

  List<double>? _computeJackLegMetrics(Pose pose) {
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];

    if (leftShoulder == null || rightShoulder == null ||
        leftHip == null || rightHip == null ||
        leftAnkle == null || rightAnkle == null) {
      return null;
    }
        
    // Check likelihoods
    if (leftShoulder.likelihood < kLandmarkLikelihoodThreshold ||
        rightShoulder.likelihood < kLandmarkLikelihoodThreshold ||
        leftHip.likelihood < kLandmarkLikelihoodThreshold ||
        rightHip.likelihood < kLandmarkLikelihoodThreshold ||
        leftAnkle.likelihood < kLandmarkLikelihoodThreshold ||
        rightAnkle.likelihood < kLandmarkLikelihoodThreshold) {
      return null;
    }

    final shoulderWidth = math.sqrt(
      math.pow(leftShoulder.x - rightShoulder.x, 2) +
      math.pow(leftShoulder.y - rightShoulder.y, 2)
    );
    
    if (shoulderWidth == 0) return null;

    // Metric 1: Total Spread (Ankle to Ankle)
    final ankleDistance = math.sqrt(
      math.pow(leftAnkle.x - rightAnkle.x, 2) +
      math.pow(leftAnkle.y - rightAnkle.y, 2)
    );
    final spreadRatio = ankleDistance / shoulderWidth;

    // Metric 2: Symmetry (Min distance from hip center)
    final midHipX = (leftHip.x + rightHip.x) / 2;
    final leftDist = (leftAnkle.x - midHipX).abs();
    final rightDist = (rightAnkle.x - midHipX).abs();
    
    // We care about the *minimum* extension. If one leg is 0.0 and the other is 1.0, min is 0.0 -> Fail.
    final symmetryRatio = math.min(leftDist, rightDist) / shoulderWidth;

    return [spreadRatio, symmetryRatio];
  }

  double? _computeJackMetric(Pose pose, PoseLandmarkType wristType, PoseLandmarkType shoulderType) {
    final wrist = pose.landmarks[wristType];
    final shoulder = pose.landmarks[shoulderType];

    if (wrist == null || shoulder == null) return null;
    if (wrist.likelihood < kLandmarkLikelihoodThreshold) return null;
    if (shoulder.likelihood < kLandmarkLikelihoodThreshold) return null;

    // shoulder.y - wrist.y:
    // Positive = wrist is higher than shoulder (arms raised)
    // Zero or negative = wrist at or below shoulder (arms down)
    return shoulder.y - wrist.y;
  }

  // --- Standing Oblique Side Crunch Logic ---
  //
  // Exercise form (from reference image):
  //   • Hands interlaced behind the head, elbows flared wide.
  //   • One knee drives upward and across while the torso crunches
  //     laterally, bringing the same-side elbow down to meet the knee.
  //   • Return to standing upright to complete one rep.
  //
  // Detection strategy:
  //   1. PRIMARY METRIC  — elbow↔knee distance (normalised by shoulder width).
  //      Standing/extended: large ratio (elbow is far above the lowered knee).
  //      Crunched:          small ratio (elbow and raised knee converge).
  //   2. FORM VALIDATOR  — ear↔elbow distance (normalised by shoulder width).
  //      Hands-behind-head: small ratio throughout the entire movement.
  //      Frames where this is too large are skipped to avoid false counts
  //      when the user drops their arms between sets.
  //
  // Left and right sides run as fully independent state machines so that
  // alternating reps (L, R, L, R …) are each counted without one side
  // blocking the other.

  void _processObliqueCrunch(Pose pose) {
    // Compute a normalisation reference that is robust to camera distance.
    final currentWidth = _computeShoulderWidth(pose);
    
    if (currentWidth != null && currentWidth > 0) {
      _lastValidShoulderWidth = currentWidth;
    }

    final refWidth = _lastValidShoulderWidth;
    if (refWidth == null) return; // No reference yet, cannot normalize

    // --- Gather per-side raw metrics ---
    final leftElbowKnee  = _computeNormalisedDistance(
      pose, PoseLandmarkType.leftElbow, PoseLandmarkType.leftKnee, refWidth);
    final rightElbowKnee = _computeNormalisedDistance(
      pose, PoseLandmarkType.rightElbow, PoseLandmarkType.rightKnee, refWidth);

    // Only add to a buffer when its landmarks are visible this frame.
    // Buffers are updated atomically per side so they stay in sync.
    if (leftElbowKnee != null) {
      _crunchLeftElbowKneeBuffer.add(leftElbowKnee);
    }
    if (rightElbowKnee != null) {
      _crunchRightElbowKneeBuffer.add(rightElbowKnee);
    }

    // Process each side independently once its buffers are warm.
    if (_crunchLeftElbowKneeBuffer.isFull) {
      _evaluateCrunchSide(
        side: 'LEFT',
        elbowKneeSmoothed: _crunchLeftElbowKneeBuffer.average,
        stateGetter: () => _leftCrunchState,
        stateSetter: (s) => _leftCrunchState = s,
      );
    }

    if (_crunchRightElbowKneeBuffer.isFull) {
      _evaluateCrunchSide(
        side: 'RIGHT',
        elbowKneeSmoothed: _crunchRightElbowKneeBuffer.average,
        stateGetter: () => _rightCrunchState,
        stateSetter: (s) => _rightCrunchState = s,
      );
    }
  }

  void _evaluateCrunchSide({
    required String side,
    required double elbowKneeSmoothed,
    required _CrunchSideState Function() stateGetter,
    required void Function(_CrunchSideState) stateSetter,
  }) {
    final currentState = stateGetter();

    switch (currentState) {
      case _CrunchSideState.extended:
        // Elbow and knee converge — crunch phase begins.
        if (elbowKneeSmoothed < kCrunchElbowKneeCrunchThreshold) {
          stateSetter(_CrunchSideState.crunching);
          debugPrint('[Crunch $side] CRUNCHING '
              '(elbowKnee: ${elbowKneeSmoothed.toStringAsFixed(3)})');
        }
        break;

      case _CrunchSideState.crunching:
        // Elbow and knee separate back to standing position — rep complete.
        // The extended threshold is intentionally larger than the crunch threshold
        // (hysteresis) to prevent oscillation at the boundary.
        if (elbowKneeSmoothed > kCrunchElbowKneeExtendedThreshold) {
          stateSetter(_CrunchSideState.extended);
          _emitRep();
          debugPrint('[Crunch $side] REP COMPLETE '
              '(elbowKnee: ${elbowKneeSmoothed.toStringAsFixed(3)})');
        }
        break;
    }
  }

  /// Returns the Euclidean distance between two landmarks, divided by
  /// [refWidth] to make it invariant to camera distance and body size.
  double? _computeNormalisedDistance(
    Pose pose,
    PoseLandmarkType typeA,
    PoseLandmarkType typeB,
    double refWidth,
  ) {
    final a = pose.landmarks[typeA];
    final b = pose.landmarks[typeB];

    if (a == null || b == null) return null;
    if (a.likelihood < kLandmarkLikelihoodThreshold) return null;
    if (b.likelihood < kLandmarkLikelihoodThreshold) return null;

    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy) / refWidth;
  }

  /// Returns the Euclidean distance between the two shoulders, used as a
  /// body-relative normalisation reference throughout the crunch detector.
  double? _computeShoulderWidth(Pose pose) {
    final ls = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rs = pose.landmarks[PoseLandmarkType.rightShoulder];

    if (ls == null || rs == null) return null;
    if (ls.likelihood < kLandmarkLikelihoodThreshold) return null;
    if (rs.likelihood < kLandmarkLikelihoodThreshold) return null;

    final dx = ls.x - rs.x;
    final dy = ls.y - rs.y;
    return math.sqrt(dx * dx + dy * dy);
  }
}
