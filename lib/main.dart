import 'package:flutter/material.dart';
import 'object_detection.dart';
import 'text_recognition.dart';
import 'barcode_scanner.dart';
import 'package:camera/camera.dart';


void main() {
  runApp(UnifiedApp());
}

class UnifiedApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Unified App for Visually Impaired',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // final PageController _pageController = PageController(initialPage: 1);
  late CameraController _cameraController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    initializeCamera();
  }

  void initializeCamera() async {
    final cameras = await availableCameras();
    _cameraController = CameraController(cameras[0], ResolutionPreset.high);
    await _cameraController.initialize();
    if(mounted){
      print("Hi IM Crying");
      setState(() {});
    }
  }

  @override
  void dispose() {
    print("camera do be disposing");
    _cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      ObjectDetectionPage(cameraController: _cameraController),
      TextRecognitionPage(cameraController: _cameraController),
      BarcodeScannerPage(cameraController: _cameraController),
    ];

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if(mounted){
            setState(() {
              _currentIndex = index;
            });
          }
        },
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.camera), label: 'Object Detection'),
          BottomNavigationBarItem(icon: Icon(Icons.text_fields), label: 'Text Recognition'),
          BottomNavigationBarItem(icon: Icon(Icons.qr_code), label: 'Barcode Scanner'),
        ],
      ),
    );
  }
}
