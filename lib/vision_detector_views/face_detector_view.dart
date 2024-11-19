import 'package:camera/camera.dart';

import 'camera_view.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
// import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:audioplayers/audioplayers.dart';

class FaceDetectorView extends StatefulWidget {
  final int drowsinessFrameThreshold;

  const FaceDetectorView({
    Key? key,
    required this.drowsinessFrameThreshold,
  }) : super(key: key);

  @override
  State<FaceDetectorView> createState() => _FaceDetectorViewState();
}

class _FaceDetectorViewState extends State<FaceDetectorView> {
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableLandmarks: true,
      enableClassification: true,
    ),
  );
  final AudioPlayer _audioPlayer = AudioPlayer();
  final double _closedEyeThreshold = 0.5; // 눈 개페율. 해당값 미만이면 감긴 것으로 판단.
  int _closedEyeFrameCount = 0;
  //final int _drowsinessFrameThreshold = 8; // ex) = 15  15프레임동안 눈 감긴상태가 지속되야 판단
  double? _leftEyeOpenProb;
  double? _rightEyeOpenProb;
  bool _isAlarmPlaying = false; // 알람 울리는중인지
  bool _showEyeCloseAlert = false; // 눈 감김 알림 상태 관리

  bool _canProcess = true;
  bool _isBusy = false;

  final _cameraLensDirection = CameraLensDirection.front;

  @override
  void dispose() {
    _canProcess = false; //이미지 처리를 중지
    _faceDetector.close();
    _audioPlayer.dispose(); // AudioPlayer 자원 해제
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 공통으로 사용할 TextStyle을 const로 정의
    const textStyle = TextStyle(color: Colors.white, fontSize: 16);
    return Stack(
      children: [
        CameraView(
          onImage: _processImage,
          initialCameraLensDirection: _cameraLensDirection,
        ),
        Container(color: Colors.black), // 카메라 뷰를 가리는 검은 배경
        // 상태 메시지
        Center(
          child: Text(
            '졸음 감지 중...',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        // 상태 정보 표시
        Positioned(
          top: 10,
          left: 10,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 20),
              Text(
                'Left Eye Open Probability: ${_leftEyeOpenProb?.toStringAsFixed(2) ?? 'N/A'}',
                style: textStyle,
              ),
              Text(
                'Right Eye Open Probability: ${_rightEyeOpenProb?.toStringAsFixed(2) ?? 'N/A'}',
                style: textStyle,
              ),
              Text(
                '_drowsinessFrameThreshold: ${widget.drowsinessFrameThreshold}',
                style: textStyle,
              ),
              Text(
                'Closed Eye Frames: $_closedEyeFrameCount',
                style: textStyle,
              ),
            ],
          ),
        ),
        // 눈 감김 알림 위젯
        if (_showEyeCloseAlert)
          Positioned(
            top: 50,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                margin: EdgeInsets.symmetric(horizontal: 20), // 좌우 여백 추가
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    // 그림자 효과 추가
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  '졸음감지!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _processImage(InputImage inputImage) async {
    if (!_canProcess) return; // 이미지 처리 할 수 있는지
    if (_isBusy) return; // 현재 이미지 처리중인지
    _isBusy = true; // 이제부터 이미지 처리 할꺼임

    final faces = await _faceDetector.processImage(inputImage); //얼굴인식, 졸음 감지 로직
    if (faces.isNotEmpty) {
      final face = faces.first;

      final double? leftEyeOpenProbability = face.leftEyeOpenProbability;
      final double? rightEyeOpenProbability = face.rightEyeOpenProbability;

      if (leftEyeOpenProbability != null && rightEyeOpenProbability != null) {
        _detectDrowsiness(leftEyeOpenProbability, rightEyeOpenProbability);
      }
    } else {
      // 얼굴이 감지되지 않으면 알람 중지
      _stopAlarm();
      setState(() {
        _showEyeCloseAlert = false; // 얼굴이 감지되지 않으면 알림 숨기기
      });
    }
    _isBusy = false; //이미지 처리 완료
  }

  void _detectDrowsiness(double leftEyeOpenProb, double rightEyeOpenProb) {
    setState(() {
      _leftEyeOpenProb = leftEyeOpenProb;
      _rightEyeOpenProb = rightEyeOpenProb;
    });
    if (leftEyeOpenProb < _closedEyeThreshold &&
        rightEyeOpenProb < _closedEyeThreshold) {
      _closedEyeFrameCount++;

      if (_closedEyeFrameCount >= widget.drowsinessFrameThreshold) {
        // 졸음 감지 - 알람 재생
        _triggerAlarm();
        setState(() {
          _showEyeCloseAlert = true;
        });
        _closedEyeFrameCount = 0;
      }
    } else {
      // 눈을 뜨면 모든 상태 초기화
      _closedEyeFrameCount = 0;
      _stopAlarm(); // 눈을 뜬 상태이면 알람 중지
      setState(() {
        _showEyeCloseAlert = false;
      });
    }
  }

  // 눈 감기면 호출
  void _triggerAlarm() async {
    if (!_isAlarmPlaying) {
      _isAlarmPlaying = true;
      await _audioPlayer.play(AssetSource('alarm.wav'));
    }
  }

  // 눈 떠지면 호출
  void _stopAlarm() async {
    if (_isAlarmPlaying) {
      await _audioPlayer.stop();
      _isAlarmPlaying = false;
    }
  }
}
