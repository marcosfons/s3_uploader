library s3_uploader;

import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart';

import 'package:amazon_cognito_identity_dart/sig_v4.dart';
import 'package:dio/dio.dart';

import 'Policy.dart';

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
  Future<String> send({@required File file, @required String imagePathInS3Bucket,   
               Function(int count, int total) onSendProgress, int expirationTime=15 }) async {

    final FormData _formData = _createFormData(file, imagePathInS3Bucket, expirationTime);

    return _dio.post(
      _endpoint, 
      data: _formData,
      onSendProgress: onSendProgress
    ).then<String>((_) => getLink(imagePathInS3Bucket));
  }


  // Send the given file 
  // providing a stream of the progress
  Stream<double> sendWithProgress({@required File file, @required String imagePathInS3Bucket,   
                                   int expirationTime=15 }) {
    
    final FormData _formData = _createFormData(file, imagePathInS3Bucket, expirationTime);

    final StreamController<double> _controllerProgress = StreamController<double>();

    _dio.post(
      _endpoint, 
      data: _formData,
      onSendProgress: (int count, int total) => _controllerProgress.add(count / total)
    ).then((_) => _controllerProgress.close())
     .catchError((error) => _controllerProgress.addError(error));

    return _controllerProgress.stream;
  }

  // Get link with the given path in S3Bucket
  String getLink(String imagePathInS3Bucket) {
    return '$_endpoint/$imagePathInS3Bucket';
  }


}

