library s3_uploader;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart';

import 'package:amazon_cognito_identity_dart/sig_v4.dart';
import 'package:dio/dio.dart';

// A uploader to s3 amazon service
class S3Uploader {
  String _endpoint;
  String _secretId;
  String _bucketName;
  String _accessId;
  String _region;

  final Dio _dio = Dio();
  
  // Constructs the class with the given credentials
  S3Uploader({String endpoint, String secretId, String bucketName, String accessId, String region}) {
    this._endpoint = endpoint;
    this._secretId = secretId;
    this._bucketName = bucketName;
    this._accessId = accessId;
    this._region = region;
  }

  // Create the payload required for requests
  FormData _createFormData(File file, String imagePathInS3Bucket, int expirationTime) {
    final int length = file.lengthSync();

    final policy = Policy.fromS3PreSignedPost(imagePathInS3Bucket, _bucketName, _accessId, expirationTime, length, region: _region);
    final key = SigV4.calculateSigningKey(_secretId, policy.datetime, _region, 's3');
    final signature = SigV4.calculateSignature(key, policy.encode());

    return FormData.fromMap({
      'key': policy.key,
      'acl': 'public-read',
      'X-Amz-Credential': policy.credential,
      'X-Amz-Algorithm': 'AWS4-HMAC-SHA256',
      'X-Amz-Date': policy.datetime,
      'Policy': policy.encode(),
      'X-Amz-Signature': signature,
      'file': MultipartFile.fromFileSync(file.path, filename: basename(imagePathInS3Bucket))
    });
  }

  // Send the given file
  Future send({@required File file, @required String imagePathInS3Bucket,   
               Function(int count, int total) onSendProgress, int expirationTime=15}) {
    final FormData _formData = _createFormData(file, imagePathInS3Bucket, expirationTime);

    return _dio.post(
      _endpoint, 
      data: _formData,
      onSendProgress: onSendProgress
    );
  }

  Stream<double> sendWithProgress({@required File file, @required String imagePathInS3Bucket,   
               int expirationTime=15}) {
    
    final FormData _formData = _createFormData(file, imagePathInS3Bucket, expirationTime);

    final StreamController<double> _controllerProgress = StreamController<double>();

    _dio.post(
      _endpoint, 
      data: _formData,
      onSendProgress: (int count, int total) => _controllerProgress.add(count / total)
    ).then((_) => _controllerProgress.close())
     .catchError((error) { 
       print('Vixe deu erro brow');
       _controllerProgress.addError(error);
     });

    return _controllerProgress.stream;
  }

}

class Policy {
  String expiration;
  String region;
  String bucket;
  String key;
  String credential;
  String datetime;
  int maxFileSize;

  Policy(this.key, this.bucket, this.datetime, this.expiration, this.credential,this.maxFileSize,
      {this.region});

  factory Policy.fromS3PreSignedPost(
    String key,
    String bucket,
    String accessKeyId,
    int expiryMinutes,
    int maxFileSize, {
    String region,
  }) {
    final datetime = SigV4.generateDatetime();
    final expiration = (DateTime.now())
        .add(Duration(minutes: expiryMinutes))
        .toUtc()
        .toString()
        .split(' ')
        .join('T');
    final cred =
        '$accessKeyId/${SigV4.buildCredentialScope(datetime, region, 's3')}';
    final policy = Policy(key, bucket, datetime, expiration, cred, maxFileSize,
        region: region);
    return policy;
  }

  String encode() {
    final bytes = utf8.encode(toString());
    return base64.encode(bytes);
  }

  @override
  String toString() {
    return '''
      { "expiration": "${this.expiration}",
        "conditions": [
          {"bucket": "${this.bucket}"},
          ["starts-with", "\$key", "${this.key}"],
          {"acl": "public-read"},
          ["content-length-range", 1, ${this.maxFileSize}],
          {"x-amz-credential": "${this.credential}"},
          {"x-amz-algorithm": "AWS4-HMAC-SHA256"},
          {"x-amz-date": "${this.datetime}" }
        ]
      }
    ''';
  }
}
