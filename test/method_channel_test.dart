import 'package:flutter_test/flutter_test.dart';
import 'package:true_compass/true_compass.dart';
import 'package:true_compass/true_compass_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final platform = MethodChannelTrueCompass();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(platform.methodChannel, null);
    messenger.setMockStreamHandler(platform.eventChannel, null);
  });

  test('default platform is the method channel', () {
    expect(TrueCompassPlatform.instance, isA<MethodChannelTrueCompass>());
  });

  test('checkAvailability maps names, unknown becomes unsupported', () async {
    String reply = 'noSensor';
    messenger.setMockMethodCallHandler(
      platform.methodChannel,
      (call) async => call.method == 'checkAvailability' ? reply : null,
    );
    expect(await platform.checkAvailability(), CompassAvailability.noSensor);
    reply = 'something-new';
    expect(await platform.checkAvailability(), CompassAvailability.unsupported);
  });

  test('requestPermission', () async {
    messenger.setMockMethodCallHandler(
      platform.methodChannel,
      (call) async =>
          call.method == 'requestPermission' ? 'permissionDenied' : null,
    );
    expect(await platform.requestPermission(),
        CompassAvailability.permissionDenied);
  });

  test('rawEvents forwards arguments and decodes maps', () async {
    Object? args;
    messenger.setMockStreamHandler(
      platform.eventChannel,
      MockStreamHandler.inline(
        onListen: (arguments, sink) {
          args = arguments;
          sink.success(
              {'kind': 'heading', 'heading': 12.5, 'compensated': true});
          sink.endOfStream();
        },
      ),
    );
    final events = await platform
        .rawEvents(
          const RawSensorConfig(
            interval: Duration(milliseconds: 20),
            compensateScreenOrientation: false,
          ),
        )
        .toList();
    expect(events.single['heading'], 12.5);
    expect(
        args, {'intervalMicros': 20000, 'compensateScreenOrientation': false});
  });
}
