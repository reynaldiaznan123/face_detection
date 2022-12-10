import 'package:camera/camera.dart';
import 'package:get/get.dart';

import '../models/camera_model.dart';

class RootBinding extends Bindings {
  @override
  void dependencies() {
    Get.putAsync(() async {
      return CameraModel(cameras: await availableCameras());
    });
  }
}