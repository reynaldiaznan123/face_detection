import 'package:camera/camera.dart';

class CameraModel {
  late final List<CameraDescription> _cameras;

  CameraModel({
    required List<CameraDescription> cameras
  }): _cameras = cameras;

  List<CameraDescription> all() {
    return _cameras;
  }

  CameraDescription find(CameraLensDirection direction) {
    return _cameras.firstWhere((element) => element.lensDirection == direction);
  }
}