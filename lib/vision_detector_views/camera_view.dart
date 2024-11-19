import 'dart:io'; // 파일 및 플랫폼 관련 기능 사용
import 'package:camera/camera.dart'; // 카메라 기능 사용
import 'package:flutter/material.dart'; // Flutter 머티리얼 디자인 위젯
import 'package:flutter/services.dart'; // 플랫폼 서비스 관련 기능

import 'package:google_mlkit_commons/google_mlkit_commons.dart'; // ML Kit 공통 기능

class CameraView extends StatefulWidget {
  const CameraView({
    Key? key,
    required this.onImage, // 이미지 처리 콜백
    this.onCameraFeedReady, // 카메라 피드 준비 완료 콜백
    this.initialCameraLensDirection = CameraLensDirection.front, // 초기 카메라 렌즈 방향
  }) : super(key: key);

  // 클래스 멤버 변수들 정의
  final Function(InputImage inputImage) onImage;
  final VoidCallback? onCameraFeedReady;
  final CameraLensDirection initialCameraLensDirection;
  @override
  State<CameraView> createState() => _CameraViewState();
}

// CameraView의 상태 관리 클래스
class _CameraViewState extends State<CameraView> {
  static List<CameraDescription> _cameras = []; // 사용 가능한 카메라 목록
  CameraController? _controller; // 카메라 컨트롤러
  int _cameraIndex = -1; // 현재 사용 중인 카메라 인덱스

  @override
  void initState() {
    super.initState();
    _initialize(); // 카메라 초기화
  }

  // 카메라 초기화 함수
  void _initialize() async {
    if (_cameras.isEmpty) {
      _cameras = await availableCameras(); // 사용 가능한 카메라 목록 가져오기
    }
    // 초기 카메라 방향에 맞는 카메라 찾기
    debugPrint('초기 카메라 개수 : ${_cameras.length}');
    for (var i = 0; i < _cameras.length; i++) {
      debugPrint('카메라 : ${_cameras[i]}'); // 0뒤, 1앞
      if (_cameras[i].lensDirection == widget.initialCameraLensDirection) {
        _cameraIndex = i;
        break;
      }
    }
    if (_cameraIndex != -1) {
      _startLiveFeed(); // 라이브 피드 시작
    }
  }

  @override
  void dispose() {
    // 위젯 dispose 시
    _stopLiveFeed(); // 라이브 피드 중지
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        // 위젯들을 겹쳐서 표시
        fit: StackFit.expand,
        children: [
          Container(
            color: Colors.black, // 배경색을 검정으로 설정
          ),
        ],
      ),
    );
  }

  // 라이브 피드 시작 함수
  Future _startLiveFeed() async {
    final camera = _cameras[_cameraIndex];
    _controller = CameraController(
      camera,
      ResolutionPreset.low, // 카메라 해상도 설정
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21 // 안드로이드용 이미지 포맷
          : ImageFormatGroup.bgra8888, // iOS용 이미지 포맷
    );

    // 카메라 초기화 및 이미지 스트림 시작
    _controller?.initialize().then((_) {
      if (!mounted) {
        return;
      }
      _controller?.startImageStream(_processCameraImage).then((value) {
        if (widget.onCameraFeedReady != null) {
          widget.onCameraFeedReady!();
        }
      });
      setState(() {});
    });
  }

  // 라이브 피드 중지 함수
  Future _stopLiveFeed() async {
    await _controller?.stopImageStream();
    await _controller?.dispose();
    _controller = null;
  }

  // 카메라 이미지 처리 함수
  //final int _frameCount = 0;
  void _processCameraImage(CameraImage image) {
    // _frameCount++;
    // if (_frameCount % 3 != 0) return; // 3번째 프레임마다 처리
    final inputImage = _inputImageFromCameraImage(image);
    if (inputImage == null) return;
    widget.onImage(inputImage); // 이미지 처리 콜백 호출
  }

  // 디바이스 방향별 회전 각도 매핑
  final _orientations = {
    DeviceOrientation.portraitUp: 0, // 세로 정방향 (기본)
    DeviceOrientation.landscapeLeft: 90, // 왼쪽으로 90도 회전 (가로)
    DeviceOrientation.portraitDown: 180, // 거꾸로 뒤집힘
    DeviceOrientation.landscapeRight: 270, // 오른쪽으로 90도 회전 (가로)
  };

  // 카메라 이미지를 InputImage로 변환하는 함수
  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_controller == null) return null;

    // 플랫폼별 이미지 회전 처리
    final camera = _cameras[_cameraIndex];
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;

    // iOS와 Android 플랫폼별 이미지 회전 처리 로직
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      // 현재 디바이스 방향에 따른 회전 각도 가져오기
      var rotationCompensation =
          _orientations[_controller!.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        // 전면 카메라일 경우의 회전 보정
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        // 후면 카메라일 경우의 회전 보정
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    if (rotation == null) return null;

    // 이미지 포맷 검증 및 변환
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) return null;

    // since format is constraint to nv21 or bgra8888, both only have one plane
    if (image.planes.length != 1) return null;
    final plane = image.planes.first;

    // 최종 InputImage 생성 및 반환
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation, // used only in Android
        format: format, // used only in iOS
        bytesPerRow: plane.bytesPerRow, // used only in iOS
      ),
    );
  }
}
