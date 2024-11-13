import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Get instance of the individual api's using instance of [Vision]
/// For example
/// To get an instance of [ImageLabeler]
/// ImageLabeler imageLabeler = GoogleMlKit.instance.imageLabeler();
class Vision {
  Vision._();

  // Creates an instance of [GoogleMlKit] by calling the private constructor
  static final Vision instance = Vision._();

  /// Get an instance of [ImageLabeler] by calling this function
  /// [imageLabelerOptions]  if not provided it creates [ImageLabeler] with [ImageLabelerOptions]
  /// You can provide either [LocalLabelerOptions] to use a custom tflite model
  /// Or [AutoMLImageLabelerOptions] to use auto ml vision model trained by you

  /// Return an instance of [FaceDetector].
  @Deprecated(
      'Use [google_mlkit_face_detection] plugin instead of [google_ml_kit].')
  FaceDetector faceDetector([FaceDetectorOptions? options]) {
    return FaceDetector(options: options ?? FaceDetectorOptions());
  }
}
