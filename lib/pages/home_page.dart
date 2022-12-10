import 'package:flutter/material.dart';
import 'package:get/get.dart';

class HomePage extends GetView {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: TextButton(
        child: const Text('Scan Wajah'),
        onPressed: () {
          Get.toNamed('/face-recognizer');
        },
      ),),
    );
  }

}