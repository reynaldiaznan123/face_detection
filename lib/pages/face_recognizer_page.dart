import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../modules/face_recognizer/controllers/face_recognizer_controller.dart';

class FaceRecognizerPage extends GetView<FaceRecognizerController> {
  const FaceRecognizerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GetBuilder<FaceRecognizerController>(
        builder: (controller) {
          if (controller.loading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (controller.camera == null) {
            print(controller.result.keys.first);
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Text("Camera empty"),
                  TextButton(
                    onPressed: () {
                      controller.start();
                    },
                    child: const Text("Start"),
                  )
                ],
              ),
            );
          }

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                controller.started
                  ? CameraPreview(controller.camera!)
                  : const Text("Camera stopped"),
                TextButton(
                  onPressed: controller.started ? null : () {
                    controller.start();
                  },
                  child: const Text("Start"),
                ),
                controller.result.isNotEmpty
                  ? Text("Name: ${controller.result.keys.first}")
                  : const Text("Tidak diketahui"),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          controller.save("Reynaldi Aznan");
        },
        backgroundColor: Colors.green,
        child: const Icon(Icons.add),
      ),
    );
  }
}