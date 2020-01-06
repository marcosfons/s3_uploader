import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:s3_uploader/s3_uploader.dart';

const String ENDPOINT_S3 = '';
const String REGION_S3 = '';
const String ACCESS_ID_S3 = '';
const String SECRET_ID_S3 = '';
const String BUCKET_NAME_S3 = '';

void onSendProgress(int count, int total) {
  print('$count/$total   ${count / total}%');
}

void main() {
  test('send an image', () async {
    final S3Uploader _uploaderS3 = S3Uploader(
      endpoint: ENDPOINT_S3,
      accessId: ACCESS_ID_S3,
      bucketName: BUCKET_NAME_S3,
      region: REGION_S3,
      secretId: SECRET_ID_S3
    );
    
    final File file = File('');

    
    await _uploaderS3.send(file: file, imagePathInS3Bucket: 'plugin/teste.png', expirationTime: 24 * 60 * 60, onSendProgress: onSendProgress)
      .then((dynamic d) {
        print(d.statusCode);
        print(d.statusMessage);
    });

    Stream<double> progress = _uploaderS3.sendWithProgress(file: file, imagePathInS3Bucket: 'plugin/comstream.png');
    progress.listen((p) => print('$p%'));


    await Future.delayed(Duration(seconds: 3), () {});
    // expect(calculator.addOne(2), 3);
    // expect(calculator.addOne(-7), -6);
    // expect(calculator.addOne(0), 1);
    // expect(() => calculator.addOne(null), throwsNoSuchMethodError);
  });
}
