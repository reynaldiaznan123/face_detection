import 'package:get/get.dart';

import '../controllers/face_recognizer_controller.dart';

class FaceRecognizerBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(FaceRecognizerController());
  }
}