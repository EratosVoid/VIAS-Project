// camera_manager.dart
import 'package:camera/camera.dart';

class CameraManager {
  static final CameraManager _instance = CameraManager._internal();

  factory CameraManager() {
    return _instance;
  }

  CameraManager._internal();

  late CameraController cameraController;
  bool isImageStreamActive = false;

  Future<void> initialize() async {
    final cameras = await availableCameras();
    cameraController = CameraController(cameras[0], ResolutionPreset.high);
    await cameraController.initialize();
  }
  void startImageStream(Function(CameraImage image) onAvailable) {
    if (cameraController.value.isStreamingImages) {
      cameraController.stopImageStream();
    }
    cameraController.startImageStream(onAvailable).catchError((e) {
      print('Error starting image stream: $e');
    });
  }

  void stopImageStream() {
    if (cameraController.value.isStreamingImages) {
      cameraController.stopImageStream().catchError((e) {
        print('Error stopping image stream: $e');
      });
    }
  }
  // Future<void> startImageStream(onAvailable) async {
  //   if (!isImageStreamActive) {
  //     await cameraController.startImageStream(onAvailable);
  //     isImageStreamActive = true;
  //   }
  // }
  //
  // Future<void> stopImageStream() async {
  //   if (isImageStreamActive) {
  //     await cameraController.stopImageStream();
  //     isImageStreamActive = false;
  //   }
  // }

  void dispose() {
    cameraController.dispose();
  }
}
