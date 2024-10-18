import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TextRecognitionPage extends StatelessWidget {
  final CameraController cameraController;

  TextRecognitionPage({required this.cameraController});

  @override
  Widget build(BuildContext context) {
    return MyHomePage(
      title: 'Text Recognition',
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
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  bool isBusy = false;
  late TextRecognizer textRecognizer;
  late Size size;
  FlutterTts flutterTts = FlutterTts();
  RecognizedText? _scanResults;
  CameraImage? img;
  bool isImageStreamActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    startImageStream();
  }

  void startImageStream() {
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      if (!isImageStreamActive && !isBusy) {
        widget.cameraController.startImageStream((image) {
          if (!isBusy) {
            isBusy = true;
            img = image;
            doTextRecognitionOnFrame();
          }
        });
        isImageStreamActive = true;
      }
    }
  }

  void stopImageStream() {
    if (isImageStreamActive) {
      try {
        widget.cameraController.stopImageStream();
      } catch (e) {
        print('Error stopping image stream: $e');
      }
      isImageStreamActive = false;
    }
  }

  @override
  void dispose() {
    print('text dispose');
    WidgetsBinding.instance.removeObserver(this);
    stopImageStream();
    textRecognizer.close();
    flutterTts.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!isBusy) startImageStream();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      stopImageStream();
    }
  }

  void doTextRecognitionOnFrame() async {
    try {
      InputImage? frameImg = getInputImage();
      if (frameImg == null) {
        isBusy = false;
        return;
      }
      RecognizedText recognizedText = await textRecognizer.processImage(frameImg);
      print("RecognizedText blocks count: ${recognizedText.blocks.length}");

      if (mounted) {
        print('text setstate');

        setState(() {
          _scanResults = recognizedText;
        });
      }

      // Speak the recognized text
      if (recognizedText.text.isNotEmpty) {
        await flutterTts.speak(recognizedText.text);
      }
    } catch (e) {
      print('Error during text recognition: $e');
    } finally {
      isBusy = false;
    }
  }

  InputImage? getInputImage() {
    try {
      final bytesBuilder = BytesBuilder();
      for (Plane plane in img!.planes) {
        bytesBuilder.add(plane.bytes);
      }
      final bytes = bytesBuilder.toBytes();

      final imageSize = Size(img!.width.toDouble(), img!.height.toDouble());

      final imageRotation = InputImageRotationValue.fromRawValue(
        widget.cameraController.description.sensorOrientation,
      ) ?? InputImageRotation.rotation0deg;

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

  Widget buildResult() {
    if (!widget.cameraController.value.isInitialized || _scanResults == null) {
      return const Text('');
    }

    final Size imageSize = Size(
      widget.cameraController.value.previewSize!.height,
      widget.cameraController.value.previewSize!.width,
    );
    CustomPainter painter = TextRecognitionPainter(imageSize, _scanResults!);
    return CustomPaint(
      painter: painter,
    );
  }

  @override
  Widget build(BuildContext context) {
    size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        title: const Center(
          child: Text(
            "Text Recognizer",
            style: TextStyle(fontSize: 25),
          ),
        ),
        backgroundColor: Colors.brown,
      ),
      backgroundColor: Colors.black,
      body: widget.cameraController.value.isInitialized
          ? Stack(
        children: [
          Positioned(
            top: 0.0,
            left: 0.0,
            width: size.width,
            height: size.height,
            child: CameraPreview(widget.cameraController),
          ),
          Positioned(
            top: 0.0,
            left: 0.0,
            width: size.width,
            height: size.height,
            child: buildResult(),
          ),
        ],
      )
          : Center(child: CircularProgressIndicator()),
    );
  }
}

class TextRecognitionPainter extends CustomPainter {
  TextRecognitionPainter(this.absoluteImageSize, this.recognizedText);

  final Size absoluteImageSize;
  final RecognizedText recognizedText;

  @override
  void paint(Canvas canvas, Size size) {
    final double scaleX = size.width / absoluteImageSize.width;
    final double scaleY = size.height / absoluteImageSize.height;

    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.brown;

    for (TextBlock block in recognizedText.blocks) {
      canvas.drawRect(
        Rect.fromLTRB(
          block.boundingBox.left * scaleX,
          block.boundingBox.top * scaleY,
          block.boundingBox.right * scaleX,
          block.boundingBox.bottom * scaleY,
        ),
        paint,
      );

      TextSpan span = TextSpan(
        text: block.text,
        style: const TextStyle(fontSize: 20, color: Colors.red),
      );
      TextPainter tp = TextPainter(
        text: span,
        textAlign: TextAlign.left,
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(
        canvas,
        Offset(block.boundingBox.left * scaleX, block.boundingBox.top * scaleY),
      );
    }
  }

  @override
  bool shouldRepaint(TextRecognitionPainter oldDelegate) {
    return oldDelegate.absoluteImageSize != absoluteImageSize ||
        oldDelegate.recognizedText != recognizedText;
  }
}
