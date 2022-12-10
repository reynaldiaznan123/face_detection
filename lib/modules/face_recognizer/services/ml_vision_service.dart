import 'package:camera/camera.dart';
import 'package:image/image.dart' as imglib;
import 'package:tflite_flutter/tflite_flutter.dart';

class MlVisionService {
  GpuDelegateV2? _gpuDelegateV2;

  Future<Interpreter?> initialize() async {
    try {
      _gpuDelegateV2 = GpuDelegateV2(
        options: GpuDelegateOptionsV2(
          isPrecisionLossAllowed: false,
          inferencePreference: TfLiteGpuInferenceUsage.fastSingleAnswer,
          inferencePriority1: TfLiteGpuInferencePriority.minLatency,
          inferencePriority2: TfLiteGpuInferencePriority.auto,
          inferencePriority3: TfLiteGpuInferencePriority.auto,
        ),
      );

      return Interpreter.fromAsset(
        'mobilefacenet.tflite',
        options: InterpreterOptions()..addDelegate(_gpuDelegateV2!),
      );
    } catch (e) {
      print(e.toString());
    }

    return null;
  }

  imglib.Image convertCameraImage(
    CameraImage image,
    CameraLensDirection direction,
  ) {
    final int width = image.width;
    final int height = image.height;
    final imglib.Image img = imglib.Image(width, height);
    const int hexFF = 0xFF000000;
    final int uvyButtonStride = image.planes[1].bytesPerRow;
    final int? uvPixelStride = image.planes[1].bytesPerPixel;
    for (int x = 0; x < width; x++) {
      for (int y = 0; y < height; y++) {
        final int uvIndex =
            uvPixelStride! * (x / 2).floor() + uvyButtonStride * (y / 2).floor();
        final int index = y * width + x;
        final yp = image.planes[0].bytes[index];
        final up = image.planes[1].bytes[uvIndex];
        final vp = image.planes[2].bytes[uvIndex];
        // Calculate pixel color
        int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
        int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91)
            .round()
            .clamp(0, 255);
        int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);
        // color: 0x FF  FF  FF  FF
        //           A   B   G   R
        img.data[index] = hexFF | (b << 16) | (g << 8) | r;
      }
    }

    if (direction == CameraLensDirection.front) {
      return imglib.copyRotate(img, -90);
    }
    return imglib.copyRotate(img, 90);
  }

  void dispose() {
    _gpuDelegateV2?.delete();
    _gpuDelegateV2 = null;
  }
}