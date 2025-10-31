import 'dart:convert';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:injectable/injectable.dart';
//import 'package:v2_practitioner_app/commons/shared_pref/i_shared_pref.dart';
//import 'package:v2_practitioner_app/infrastructure/env/api_constants.dart';

import 'api_failure.dart';

@injectable
class ApiService {
  final Client client;

  ApiService(this.client);

  Future<Either<ApiFailure, E>> post<E>(
    String url,
    Map<String, dynamic>? body,
    E Function(dynamic) fromJsonE,
  ) async {
    return sendRequest<E>(url, body, fromJsonE, RequestType.POST);
  }

  Future<Either<ApiFailure, E>> postFormData<E>(
    String url,
    Map<String, dynamic>? body,
    E Function(dynamic) fromJsonE,
  ) async {
    return sendRequest<E>(url, body, fromJsonE, RequestType.FORM_DATA_POST);
  }

  Future<Either<ApiFailure, E>> put<E>(
    String url,
    dynamic body,
    E Function(Object?) fromJsonE,
  ) async {
    return sendRequest<E>(url, body, fromJsonE, RequestType.PUT);
  }

  Future<Either<ApiFailure, E>> patch<E>(
    String url,
    Map<String, dynamic>? body,
    E Function(dynamic) fromJsonE,
    String Function(Map<String, dynamic>?) readAPIError,
  ) async {
    return sendRequest<E>(url, body, fromJsonE, RequestType.PATCH);
  }

  Future<Either<ApiFailure, E>> delete<E>(
    String url,
    E Function(dynamic) fromJsonE,
  ) async {
    return sendRequest<E>(url, null, fromJsonE, RequestType.DELETE);
  }

  Future<Either<ApiFailure, E>> get<E>(
    String url,
    E Function(dynamic) fromJsonE, {
    Map<String, String>? queryParams,
  }) async {
    return sendRequest<E>(
      url,
      null,
      fromJsonE,
      RequestType.GET,
      queryParams: queryParams,
    );
  }

  Future<Map<String, String>> _getHeader(RequestType type) async {
    final token ="";
    Map<String, String> map = {};

    if (RequestType.FORM_DATA_POST != type) {
      map['content-type'] = 'application/json';
    }

    if (token.isNotEmpty) {
      map['Authorization'] = 'Bearer $token';
    }

    return map;
  }

  Future<Either<ApiFailure, E>> sendRequest<E>(
    String url,
    dynamic body,
    E Function(dynamic) fromJsonE,
    RequestType type, {
    Map<String, String>? headers,
    Map<String, String>? queryParams,
  }) async {
    try {
      final headers = await _getHeader(type);

      Uri uri = Uri.parse(url);

      if (queryParams != null) {
        uri = uri.replace(queryParameters: queryParams);
      }
      debugPrint('REQ URL : ${uri.toString()}');
      debugPrint('HEADERS : ${headers.toString()}');
      debugPrint('BODY : ${body.toString()}');

      var response = switch (type) {
        RequestType.GET => await client.get(uri, headers: headers),
        RequestType.POST => await client.post(
          uri,
          body: jsonEncode(body),
          headers: headers,
        ),
        RequestType.FORM_DATA_POST => await client.post(
          uri,
          body: body,
          headers: headers,
        ),
        RequestType.PATCH => await client.patch(uri, body: jsonEncode(body)),
        RequestType.PUT => await client.put(
          uri,
          body: jsonEncode(body),
          headers: headers,
        ),
        RequestType.DELETE => await client.delete(uri, headers: headers),
      };
      debugPrint('REQ -> ${url}');
      debugPrint('RESP CODE : ${response.statusCode.toString()}');
      dynamic decodedJson = response.body.isNotEmpty
          ? jsonDecode(response.body)
          : null;

      debugPrint('RESP -> ${decodedJson?.toString()}');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseObj = fromJsonE(decodedJson ?? {});
        return Right(responseObj);
      } else {
        return Left(
          ApiFailure.serverError(
            message: consolidateErrorMessages(decodedJson),
          ),
        );
      }
    } catch (e) {
      debugPrint('<>e $url :${e.toString()}');
      if (e is SocketException) {
        return const Left(
          ApiFailure.clientError(message: 'Failed to connect to server.'),
        );
      }
      return const Left(
        ApiFailure.clientError(message: 'An unknown error occurred.!'),
      );
    }
  }

  Future<Either<ApiFailure, E>> onPractitionerExcelUpload<E>(
    String fileName,
    List<int> fileBytes,
    List<String?> organizationIds,
    E Function(dynamic) fromJsonE,
  ) async {
    try {

      String url='';

      final token ="";
      final headers = {
        'content-type': 'multipart/form-data',
        'Authorization': 'Bearer $token',
      };

      debugPrint('<> Upload URL: $url \n Headers : \n $headers');

      final request = http.MultipartRequest('POST', Uri.parse(url))
        ..headers.addAll(headers);

      request.files.add(
        http.MultipartFile.fromBytes(
          'practitioners', // field name
          fileBytes,
          filename: fileName,
        ),
      );

      for (final id in organizationIds) {
        if (id != null) {
          request.fields['organization[]'] = id;
        }
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('Bulk Import Request:\n ${request.fields}');
      debugPrint('Bulk Import Response status:\n ${response.statusCode}');
      debugPrint('Bulk Import Response body: \n${response.body}');

      final decodedJson = response.body.isNotEmpty
          ? jsonDecode(response.body)
          : null;

      if (response.statusCode == 200 || response.statusCode == 204) {
        final responseObj = fromJsonE(decodedJson);
        return Right(responseObj);
      } else if (response.statusCode == 401) {
        // await _pref.clear();
        // await AuthUtils.clearToken();
        return Left(
          ApiFailure.serverError(
            message: consolidateErrorMessages(decodedJson),
          ),
        );
      } else {
        return Left(
          ApiFailure.serverError(
            message: consolidateErrorMessages(decodedJson),
          ),
        );
      }
    } catch (e) {
      debugPrint('Upload Error: $e');

      if (e is SocketException) {
        return Left(
          ApiFailure.clientError(message: consolidateErrorMessages(e)),
        );
      }

      return const Left(
        ApiFailure.clientError(message: 'An unknown error occurred.'),
      );
    }
  }

  Future<Either<ApiFailure, E>> multiPartFileUpload<E>(
    String filePath,
    String tag,
    String url,
    Map<String, dynamic> body,
    E Function(dynamic) fromJsonE,
  ) async {
    try {
      bool isFileUpload = false;
      var headers = {
        'content-type': 'multipart/form-data',
        'Authorization':
            'Bearer ',
      };
      debugPrint('<>url $url');
      var request = http.MultipartRequest('POST', Uri.parse(url))
        ..headers.addAll(headers);

      if (filePath != '') {
        isFileUpload = true;

        request.files.add(
          await http.MultipartFile.fromPath(
            tag,
            filePath,
            filename: filePath.split('/').last,
          ),
        );
      }

      body.forEach((key, value) {
        if (!isFileUpload) {
          if (key == 'profile_image') {
            request.fields[key] = "";
          } else {
            request.fields[key] = value;
          }
        } else {
          if (key != 'profile_image') {
            request.fields[key] = value;
          }
        }

        //remove profile_image from form-data
      });

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      debugPrint('Response url: $url');
      debugPrint('Response Status Code: ${response.statusCode}');
      var decodedJson = response.body.isNotEmpty
          ? jsonDecode(response.body)
          : null;

      debugPrint('Response Body: ${jsonEncode(decodedJson).toString()}');
      if (response.statusCode == 200 || response.statusCode == 204) {
        final responseObj = fromJsonE(decodedJson);
        return Right(responseObj);
      } else {
        return Left(
          ApiFailure.serverError(
            message: getValidationMessage(decodedJson) ?? "",
          ),
        );
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (e is SocketException) {
        return const Left(
          ApiFailure.clientError(message: 'Failed to connect to server.'),
        );
      }
      return const Left(
        ApiFailure.clientError(message: 'An unknown error occurred.'),
      );
    }
  }

  Future<Either<ApiFailure, E>> multiPartFileUploadToClient<E>(
    String filePath,
    String tag,
    String url,
    Map<String, dynamic> body,
    String jwtToken,
    E Function(dynamic) fromJsonE,
  ) async {
    try {
      var headers = {'Authorization': 'Bearer $jwtToken'};

      var request = http.MultipartRequest('POST', Uri.parse(url))
        ..headers.addAll(headers);

      if (filePath != '') {
        request.files.add(
          await http.MultipartFile.fromPath(
            tag,
            filePath,
            filename: filePath.split('/').last,
          ),
        );
      }

      debugPrint('<>Request Body :$body');

      body.forEach((key, value) {
        request.fields[key] = value;
      });

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      debugPrint('Response url: ${url}');
      debugPrint('Response Status Code: ${response.statusCode}');
      var decodedJson = response.body.isNotEmpty
          ? jsonDecode(response.body)
          : null;

      debugPrint('Response Body: ${decodedJson?.toString()}');
      if (response.statusCode == 200 || response.statusCode == 204) {
        final responseObj = fromJsonE(decodedJson);
        return Right(responseObj);
      } else {
        return Left(
          ApiFailure.serverError(
            message: consolidateErrorMessages(decodedJson),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (e is SocketException) {
        return const Left(
          ApiFailure.clientError(message: 'Failed to connect to server.'),
        );
      }
      return const Left(
        ApiFailure.clientError(message: 'An unknown error occurred.'),
      );
    }
  }

  String? getValidationMessage(dynamic decodedJson) {
    if (decodedJson == null || decodedJson['errors'] == null) {
      return null;
    }
    return (decodedJson['errors'] as Map<String, dynamic>).values
        .expand((value) => value.split('|'))
        .join('\n');
  }
}

String consolidateErrorMessages(dynamic data) {
  final Map<String, dynamic>? errors = data['errors'] as Map<String, dynamic>?;

  if (errors == null || errors.isEmpty) {
    return data['message'] as String? ?? 'An unknown error occurred';
  }
  final List<String> consolidatedErrors = [];
  errors.forEach((field, message) {
    final List<String> fieldErrors = (message as String).split('|');
    for (String error in fieldErrors) {
      consolidatedErrors.add(error.capitalize ?? error);
    }
  });
  return consolidatedErrors.join('\n');
}

enum RequestType { POST, PATCH, GET, PUT, DELETE, FORM_DATA_POST }
