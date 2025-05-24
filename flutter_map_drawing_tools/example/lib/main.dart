import 'package:flutter/material.dart';
// import 'package:flutter_map/flutter_map.dart';
// import 'package:flutter_map_drawing_tools/flutter_map_drawing_tools.dart';
// import 'package:latlong2/latlong.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Drawing Tools Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // final DrawingToolsController _drawingToolsController = DrawingToolsController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Map Drawing Tools Example'),
      ),
      body: Center(
        child: Text(
          'Flutter Map with Drawing Tools will be here.',
          // Replace with FlutterMap widget and DrawingTools widget/layer
        ),
      ),
      // floatingActionButton: FloatingActionButton(
      //   onPressed: () {
      //     // Example: Activate a drawing mode
      //     // _drawingToolsController.setDrawingMode(DrawingMode.Polygon);
      //   },
      //   tooltip: 'Draw Polygon',
      //   child: const Icon(Icons.polyline),
      // ),
    );
  }
}
