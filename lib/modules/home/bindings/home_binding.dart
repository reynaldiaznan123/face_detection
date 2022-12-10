import 'package:get/get.dart';

import '../../face_recognizer/controllers/face_recognizer_controller.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.delete<FaceRecognizerController>();
  }
}