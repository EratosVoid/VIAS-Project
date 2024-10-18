import 'dart:io';
import 'dart:typed_data'; // For BytesBuilder
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart'; // For rootBundle

List<DetectedObject> _scanResults = [];

class ObjectDetectionPage extends StatelessWidget {
  final CameraController cameraController;

  ObjectDetectionPage({required this.cameraController});

  @override
  Widget build(BuildContext context) {
    return MyHomePage(
      title: 'Object Detector',
      cameraController: cameraController,
    );
  }
}

class MyHomePage extends StatefulWidget {
  final String title;
  final CameraController cameraController;

  MyHomePage({Key? key, required this.title, required this.cameraController})
      : super(key: key);

  @override
  MyHomePageState createState() => MyHomePageState();
}

class MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  bool isBusy = false;
  late ObjectDetector objectDetector;
  late Size size;
  CameraImage? img;
  late FlutterTts flutterTts;

  @override
  void initState() {
    super.initState();
    flutterTts = FlutterTts();
    WidgetsBinding.instance.addObserver(this);
    initializeDetector();
    startImageStream();
  }

  void initializeDetector() async {
    final modelPath = await getModelPath('assets/ml/1.tflite');
    final options = LocalObjectDetectorOptions(
      mode: DetectionMode.stream,
      classifyObjects: true,
      multipleObjects: true,
      modelPath: modelPath,
    );
    objectDetector = ObjectDetector(options: options);
  }

  Future<String> getModelPath(String assetPath) async {
    // Copy the asset to a file accessible to the app
    final appSupportDir = await getApplicationSupportDirectory();
    final modelFile = File('${appSupportDir.path}/$assetPath');

    if (!await modelFile.exists()) {
      // Ensure the parent directory exists
      await modelFile.parent.create(recursive: true);
      // Copy from assets
      final byteData = await rootBundle.load(assetPath);
      await modelFile.writeAsBytes(byteData.buffer.asUint8List());
    }

    return modelFile.path;
  }
  void startImageStream() {
    if (widget.cameraController.value.isStreamingImages) {
      print('Image stream is already running.');
      return;
    }
    try {
      widget.cameraController.startImageStream((image) {
        if (!isBusy) {
          isBusy = true;
          img = image;
          doObjectDetectionOnFrame();
        }
      });
    } catch (e) {
      print('Error starting image stream: $e');
    }
  }
  // void startImageStream() {
  //   try {
  //     widget.cameraController.startImageStream((image) {
  //       if (!isBusy) {
  //         isBusy = true;
  //         img = image;
  //         doObjectDetectionOnFrame();
  //       }
  //     });
  //   } catch (e) {
  //     print('Error starting image stream: $e');
  //   }
  // }

  // void stopImageStream() {
  //   try {
  //     widget.cameraController.stopImageStream();
  //   } catch (e) {
  //     print('Error stopping image stream: $e');
  //   }
  // }

  void stopImageStream() {
    Future.delayed(Duration(milliseconds: 50), () {
      try {
        widget.cameraController.stopImageStream();
      } catch (e) {
        print('Error stopping image stream: $e');
      }
    });
  }



  @override
  void dispose() {
    print('object dispose');
    WidgetsBinding.instance.removeObserver(this);
    stopImageStream();
    objectDetector.close();
    flutterTts.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      startImageStream();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      stopImageStream();
    }
  }

  void doObjectDetectionOnFrame() async {
    InputImage? frameImg = getInputImage();
    if (frameImg == null) {
      print('InputImage is null');
      isBusy = false;
      return;
    }
    List<DetectedObject> objects = await objectDetector.processImage(frameImg);
    print("Detected ${objects.length} objects");
    if(mounted){
      setState(() {
        print('object setstate');
        _scanResults = objects;
      });
    }
    if (objects.isNotEmpty) {
      for (DetectedObject detectedObject in objects) {
        var labels = detectedObject.labels;
        if (labels.isNotEmpty) {
          var label = labels.first.text;
          await flutterTts.speak("Detected object: $label");
        }
      }
    }
    isBusy = false;
  }

  InputImage? getInputImage() {
    try {
      final bytesBuilder = BytesBuilder();
      for (Plane plane in img!.planes) {
        bytesBuilder.add(plane.bytes);
      }
      final bytes = bytesBuilder.toBytes();

      final imageSize = Size(img!.width.toDouble(), img!.height.toDouble());

      final imageRotation = _rotationIntToImageRotation(
        widget.cameraController.description.sensorOrientation,
      );

      final inputImageFormat = Platform.isAndroid
          ? InputImageFormat.nv21
          : InputImageFormat.bgra8888;

      final bytesPerRow = img!.planes.first.bytesPerRow;

      final inputImageMetadata = InputImageMetadata(
        size: imageSize,
        rotation: imageRotation,
        format: inputImageFormat,
        bytesPerRow: bytesPerRow,
      );

      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: inputImageMetadata,
      );

      return inputImage;
    } catch (e) {
      print("Error creating InputImage: $e");
      return null;
    }
  }

  InputImageRotation _rotationIntToImageRotation(int rotation) {
    switch (rotation) {
      case 0:
        return InputImageRotation.rotation0deg;
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  Widget buildResult() {
    if (!widget.cameraController.value.isInitialized) {
      return const Text('');
    }

    final Size imageSize = Size(
      widget.cameraController.value.previewSize!.height,
      widget.cameraController.value.previewSize!.width,
    );
    CustomPainter painter = ObjectDetectorPainter(imageSize, _scanResults);
    return CustomPaint(
      painter: painter,
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> stackChildren = [];
    size = MediaQuery.of(context).size;
    if (widget.cameraController.value.isInitialized) {
      stackChildren.add(
        Positioned(
          top: 0.0,
          left: 0.0,
          width: size.width,
          height: size.height,
          child: AspectRatio(
            aspectRatio: widget.cameraController.value.aspectRatio,
            child: CameraPreview(widget.cameraController),
          ),
        ),
      );

      stackChildren.add(
        Positioned(
          top: 0.0,
          left: 0.0,
          width: size.width,
          height: size.height,
          child: buildResult(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Object Detector"),
        backgroundColor: Colors.pinkAccent,
      ),
      backgroundColor: Colors.black,
      body: Container(
        margin: const EdgeInsets.only(top: 0),
        color: Colors.black,
        child: Stack(
          children: stackChildren,
        ),
      ),
    );
  }
}

class ObjectDetectorPainter extends CustomPainter {
  ObjectDetectorPainter(this.absoluteImageSize, this.objects);

  final Size absoluteImageSize;
  final List<DetectedObject> objects;

  @override
  void paint(Canvas canvas, Size size) {
    final double scaleX = size.width / absoluteImageSize.width;
    final double scaleY = size.height / absoluteImageSize.height;

    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.pinkAccent;

    for (DetectedObject detectedObject in objects) {
      canvas.drawRect(
        Rect.fromLTRB(
          detectedObject.boundingBox.left * scaleX,
          detectedObject.boundingBox.top * scaleY,
          detectedObject.boundingBox.right * scaleX,
          detectedObject.boundingBox.bottom * scaleY,
        ),
        paint,
      );

      for (Label label in detectedObject.labels) {
        print("${label.text} ${label.confidence.toStringAsFixed(2)}");
        TextSpan span = TextSpan(
          text: label.text,
          style: const TextStyle(fontSize: 25, color: Colors.blue),
        );
        TextPainter tp = TextPainter(
          text: span,
          textAlign: TextAlign.left,
          textDirection: TextDirection.ltr,
        );
        tp.layout();
        tp.paint(
          canvas,
          Offset(detectedObject.boundingBox.left * scaleX,
              detectedObject.boundingBox.top * scaleY),
        );
        break;
      }
    }
  }

  @override
  bool shouldRepaint(ObjectDetectorPainter oldDelegate) {
    return oldDelegate.absoluteImageSize != absoluteImageSize ||
        oldDelegate.objects != objects;
  }
}
