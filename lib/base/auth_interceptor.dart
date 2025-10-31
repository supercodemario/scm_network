import 'dart:developer';

import 'package:http_interceptor/http_interceptor.dart';


class AuthorizationInterceptor implements InterceptorContract {

  AuthorizationInterceptor();
  @override
  Future<BaseRequest> interceptRequest({required BaseRequest request}) async {
    try {
      final token = "";
      if (token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
    } catch (e) {
      log(e.toString());
    }
    request.headers['Accept'] = 'application/json';
    request.headers['Content-Type'] = 'application/json';

    return request;
  }

  @override
  Future<BaseResponse> interceptResponse({
    required BaseResponse response,
  }) async {
    return response;
  }

  @override
  Future<bool> shouldInterceptRequest() async {
    return true;
  }

  @override
  Future<bool> shouldInterceptResponse() async {
    return true;
  }
}
