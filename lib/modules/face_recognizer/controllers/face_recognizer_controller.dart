import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as imglib;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../../../root/models/camera_model.dart';
import '../services/ml_vision_service.dart';

final List<FaceDetector> _detectors = [];

final Map<String, List> _data = {};

class FaceRecognizerController extends GetxController {
  CameraController? _cameraController;
  late final CameraDescription _camera;
  final CameraModel _cameraModel = Get.find<CameraModel>();
  Interpreter? _interpreter;
  final _mlVisionService = MlVisionService();
  final double _threshold = 1.0;

  List _face = [];

  Map<String, Face> _result = {};

  bool loading = true;

  bool started = false;

  bool _verify = false;

  CameraController? get camera => _cameraController;

  List get face => _face;

  Map<String, Face> get result => _result;

  StreamController<CameraImage>? _streamController;

  StreamSubscription? _streamSubscription;

  @override
  void onInit() {
    _camera = _cameraModel.find(
      CameraLensDirection.front,
    );

    _create();

    super.onInit();

    _mlVisionService.initialize().then((interpreter) {
      _interpreter = interpreter;

      if (_interpreter != null) {
        _cameraController?.initialize().then((_) {
          loading = false;

          update();

          start();
        }).catchError((_) {
          loading = false;

          update();
        });
      }
    });
  }

  @override
  void onClose() {
    _dispose();

    super.onClose();
  }

  start() {
    if (started && camera != null) {
      return;
    }

    if (_cameraController == null) {
      _create();
    }

    final InputImageRotation rotation = _rotation(
      _camera.sensorOrientation,
    );
    final Map<String, Face> result = {};
    _streamSubscription = _streamController?.stream.listen((image) async {
      try {
        final List<Face> faces = await _detect(image, rotation);

        imglib.Image converted = _mlVisionService.convertCameraImage(
          image,
          CameraLensDirection.front,
        );

        for (Face face in faces) {
          double x, y, w, h;

          x = face.boundingBox.left - 10;
          y = face.boundingBox.top - 10;
          w = face.boundingBox.width + 10;
          h = face.boundingBox.height + 10;

          imglib.Image cropped = imglib.copyCrop(
            converted,
            x.round(),
            y.round(),
            w.round(),
            h.round(),
          );
          cropped = imglib.copyResizeCropSquare(cropped, 112);

          final String output = _recognition(cropped);
          if (output != '') {
            result[output] = face;
          }
        }

        if (result.isNotEmpty) {
          _result = result;

          update();
        }
      } catch (_) {
        Get.back();
      }
    });

    // Memulai mengaktifkan kamera
    _cameraController?.startImageStream((image) async {
      if (started == false) {
        started = true;

        update();
      }

      if (_streamController?.isClosed == false) {
        _streamController?.add(image);
      }
    });
  }

  stop() async {
    await _cameraController?.stopImageStream();
    await _streamSubscription?.cancel();
    await _streamController?.close();

    for (FaceDetector detector in _detectors) {
      detector.close();

      _detectors.removeWhere((element) {
        return element.id == detector.id;
      });
    }

    started = false;

    update();
  }

  save(String name) {
    stop().then((_) {
      started = false;

      update();

      // Simpan data didalam memori
      // Bisa menggunakan database
      // Set data data didalam mysql sebagi long text jadi kan data sebagai json
      // Jika pakai mongodb langsung masukkan data nya saja
      _data[name] = _face;
    });
  }

  _dispose() {
    _cameraController?.dispose();
    _mlVisionService.dispose();
    _interpreter?.close();
    _streamController?.close();

    for (FaceDetector detector in _detectors) {
      detector.close();

      _detectors.removeWhere((element) {
        return element.id == detector.id;
      });
    }

    _cameraController = null;
    _interpreter = null;
  }

  _create() {
    _cameraController = CameraController(
      _camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    _streamController = StreamController();
  }

  Future<List<Face>> _detect(
    CameraImage image,
    InputImageRotation rotation,
  ) async  {
    try {
      final WriteBuffer writer = WriteBuffer();
      for (Plane plane in image.planes) {
        writer.putUint8List(plane.bytes);
      }

      final Uint8List bytes = writer.done().buffer.asUint8List();
      final InputImageFormat? format = InputImageFormatValue.fromRawValue(
        image.format.raw,
      );
      final InputImageData data = InputImageData(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        imageRotation: rotation,
        inputImageFormat: format ?? InputImageFormat.nv21,
        planeData: image.planes.map((plane) {
          return InputImagePlaneMetadata(
            bytesPerRow: plane.bytesPerRow,
            height: plane.height,
            width: plane.width,
          );
        }).toList(),
      );
      final FaceDetector detector = FaceDetector(
        options: FaceDetectorOptions(
          enableContours: true,
          enableClassification: true,
          performanceMode: FaceDetectorMode.accurate,
        ),
      );

      final List<Face> faces = await detector.processImage(
        InputImage.fromBytes(
          bytes: bytes,
          inputImageData: data,
        ),
      );

      return faces;
    } catch (_) {
    }

    return [];
  }

  InputImageRotation _rotation(int rotation) {
    switch (rotation) {
      case 0:
        return InputImageRotation.rotation0deg;
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      default:
        return InputImageRotation.rotation270deg;
    }
  }

  String _recognition(imglib.Image image) {
    List input = _converted(image, 112, 128, 128);
    input = input.reshape([1, 112, 112, 3]);

    List output = List.filled(1 * 192, null).reshape([1, 192]);

    _interpreter?.run(input, output);

    output = output.reshape([192]);

    if (_interpreter != null) {
      _face = List.from(output);
    }

    return _compare(_face);
  }

  Float32List _converted(
    imglib.Image image,
    int size,
    double mean,
    double std,
  ) {
    final Float32List converted = Float32List(1 * size * size * 3);
    final Float32List buffer = Float32List.view(converted.buffer);

    int index = 0;
    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        int pixel = image.getPixel(x, y);
        buffer[index++] = (imglib.getRed(pixel) - mean) / std;
        buffer[index++] = (imglib.getGreen(pixel) - mean) / std;
        buffer[index++] = (imglib.getBlue(pixel) - mean) / std;
      }
    }

    return converted.buffer.asFloat32List();
  }

  String _compare(List data) {
    double min = 999;
    double dist = 0.0;
    String response = "unknown";
    for (String label in _data.keys) {
      dist = _euclidean(_data[label]!, data);
      if (dist <= _threshold && dist < min) {
        min = dist;
        response = label;
        if (_verify == false) {
          _verify = true;
        }
      }
    }
    return response;
  }

  _euclidean(List e1, List e2) {
    double sum = 0.0;
    for (int i = 0; i < e1.length; i++) {
      sum += math.pow((e1[i] - e2[i]), 2);
    }
    return math.sqrt(sum);
  }
}