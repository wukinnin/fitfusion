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

// State Machine 3 — Side Oblique Crunches
enum _CrunchState { extended, leftCrunchDown, rightCrunchDown }

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

  _CrunchState _crunchState = _CrunchState.extended;
  final _LandmarkBuffer _crunchLeftBuffer = _LandmarkBuffer(kLandmarkBufferWindowSize);
  final _LandmarkBuffer _crunchRightBuffer = _LandmarkBuffer(kLandmarkBufferWindowSize);

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
    _crunchState = _CrunchState.extended;
    _squatBuffer.clear();
    _jackLeftBuffer.clear();
    _jackRightBuffer.clear();
    _jackLegSpreadBuffer.clear();
    _jackLegSymmetryBuffer.clear();
    _crunchLeftBuffer.clear();
    _crunchRightBuffer.clear();
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
        !_jackLegSymmetryBuffer.isFull) return;

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
        leftAnkle == null || rightAnkle == null) return null;
        
    // Check likelihoods
    if (leftShoulder.likelihood < kLandmarkLikelihoodThreshold ||
        rightShoulder.likelihood < kLandmarkLikelihoodThreshold ||
        leftHip.likelihood < kLandmarkLikelihoodThreshold ||
        rightHip.likelihood < kLandmarkLikelihoodThreshold ||
        leftAnkle.likelihood < kLandmarkLikelihoodThreshold ||
        rightAnkle.likelihood < kLandmarkLikelihoodThreshold) return null;

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

  // --- Oblique Crunch Logic ---

  void _processObliqueCrunch(Pose pose) {
    final leftDist = _computeCrunchDistance(
      pose, PoseLandmarkType.leftWrist, PoseLandmarkType.leftHip);
    final rightDist = _computeCrunchDistance(
      pose, PoseLandmarkType.rightWrist, PoseLandmarkType.rightHip);

    if (leftDist != null) _crunchLeftBuffer.add(leftDist);
    if (rightDist != null) _crunchRightBuffer.add(rightDist);

    if (!_crunchLeftBuffer.isFull || !_crunchRightBuffer.isFull) return;

    final leftSmoothed = _crunchLeftBuffer.average;
    final rightSmoothed = _crunchRightBuffer.average;

    switch (_crunchState) {
      case _CrunchState.extended:
        // Detect crunch: wrist gets close to same-side hip
        if (leftSmoothed < kCrunchWristHipProximityThreshold) {
          _crunchState = _CrunchState.leftCrunchDown;
          debugPrint('[RepDetector] Left crunch DOWN');
        } else if (rightSmoothed < kCrunchWristHipProximityThreshold) {
          _crunchState = _CrunchState.rightCrunchDown;
          debugPrint('[RepDetector] Right crunch DOWN');
        }
        break;

      case _CrunchState.leftCrunchDown:
        // The 1.5x multiplier creates hysteresis — prevents oscillation
        // at the threshold boundary from causing rapid false reps
        if (leftSmoothed > kCrunchWristHipProximityThreshold * 1.5) {
          _crunchState = _CrunchState.extended;
          _emitRep();
        }
        break;

      case _CrunchState.rightCrunchDown:
        if (rightSmoothed > kCrunchWristHipProximityThreshold * 1.5) {
          _crunchState = _CrunchState.extended;
          _emitRep();
        }
        break;
    }
  }

  double? _computeCrunchDistance(Pose pose, PoseLandmarkType wristType, PoseLandmarkType hipType) {
    final wrist = pose.landmarks[wristType];
    final hip = pose.landmarks[hipType];

    if (wrist == null || hip == null) return null;
    if (wrist.likelihood < kLandmarkLikelihoodThreshold) return null;
    if (hip.likelihood < kLandmarkLikelihoodThreshold) return null;

    // Euclidean distance in normalized coordinate space
    final dx = wrist.x - hip.x;
    final dy = wrist.y - hip.y;
    return math.sqrt(dx * dx + dy * dy);
  }
}
