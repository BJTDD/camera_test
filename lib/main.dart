import 'package:flutter/material.dart';
import 'vision_detector_views/face_detector_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Home(),
    );
  }
}

class Home extends StatefulWidget {
  const Home({Key? key}) : super(key: key);

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int _drowsinessFrameThreshold = 8; // 초기값 설정
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Google ML Kit Demo App'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  ExpansionTile(
                    title: const Text('Vision APIs'),
                    children: [
                      SizedBox(height: 20),
                      Text(
                        '졸음 감지 민감도 설정: $_drowsinessFrameThreshold 프레임',
                        style: TextStyle(fontSize: 16),
                      ),
                      Slider(
                        value: _drowsinessFrameThreshold.toDouble(),
                        min: 1,
                        max: 30,
                        divisions: 25,
                        label: _drowsinessFrameThreshold.toString(),
                        onChanged: (value) {
                          setState(() {
                            _drowsinessFrameThreshold = value.toInt();
                          });
                        },
                      ),
                      SizedBox(height: 20),
                      CustomCard(
                          'Face Detection',
                          () => FaceDetectorView(
                                drowsinessFrameThreshold:
                                    _drowsinessFrameThreshold,
                              )),
                    ],
                  ),
                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CustomCard extends StatelessWidget {
  final String _label;
  final Widget Function() _viewPageBuilder;
  final bool featureCompleted;

  const CustomCard(
    this._label,
    this._viewPageBuilder, {
    Key? key,
    this.featureCompleted = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 5,
      margin: EdgeInsets.only(bottom: 10),
      child: ListTile(
        tileColor: Theme.of(context).primaryColor,
        title: Text(
          _label,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        onTap: () {
          if (!featureCompleted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content:
                    const Text('This feature has not been implemented yet')));
          } else {
            Navigator.push(context,
                MaterialPageRoute(builder: (context) => _viewPageBuilder()));
          }
        },
      ),
    );
  }
}
