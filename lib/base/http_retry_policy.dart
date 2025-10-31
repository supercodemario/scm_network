import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_interceptor/http_interceptor.dart';


class ExpiredTokenRetryPolicy extends RetryPolicy {
  //final sharedPref = getIt<ISharedPref>();

  @override
  int get maxRetryAttempts => 4;
  bool _isRefreshing = false;
  late Completer<void> _completer;

  @override
  Future<bool> shouldAttemptRetryOnResponse(BaseResponse response) async {
    try {
      //Auth token expired
      if (response.statusCode == 401) {
        if (_isRefreshing) {
          await _completer.future;
          return true;
        }

        final url = response.request?.url;
        return refreshToken(url?.toString());
      }
    } on Exception catch (_) {}
    return false;
  }

  Future<bool> refreshToken(String? parentUrl) async {
    _isRefreshing = true;
    _completer = Completer();
    String refreshToken = "";

    if (refreshToken.isEmpty) {
      _isRefreshing = false;
      _logoutUser();
      return false;
    }

    // TODO add your refresh token API here
    final url = Uri.parse("");
    final request = {'refresh_token': refreshToken};
    debugPrint('Refresh Req Body : ${request.toString()}');

    final response = await http.post(
      url,
      body: jsonEncode(request),
      headers: {'Content-Type': 'application/json'},
    );
    debugPrint('Refresh Resp   : ${response.toString()}');
    debugPrint('Refresh Resp Code : ${response.statusCode}');

    debugPrint('Refresh Resp Body : ${response.body.toString()}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      final Map<String, dynamic> body = jsonDecode(response.body);
      final newAccessToken = body['access_token'];
      final newRefreshToken = body['refresh_token'];
      // await sharedPref.saveAccessToken(newAccessToken);
      // await sharedPref.saveRefreshToken(newRefreshToken);
      _isRefreshing = false;
      return true;
    } else {
      await _logoutUser();
      _isRefreshing = false;
      return false;
    }
  }

  Future<void> _logoutUser() async {
    // await sharedPref.clear();
    // AuthUtils.clearToken();
  }
}
