library woocommerce_rest_api;

import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart' as crypto;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:woocommerce_rest_api/src/models/woo_product.dart';
import 'package:woocommerce_rest_api/src/models/woo_category.dart';
import 'package:woocommerce_rest_api/src/models/woo_review.dart';
import 'package:woocommerce_rest_api/src/models/woo_customer.dart';
import 'package:woocommerce_rest_api/src/models/woo_cart_list.dart';
import 'package:woocommerce_rest_api/src/models/woo_order.dart';
import 'package:woocommerce_rest_api/src/models/ti_wishlist.dart';
import 'package:woocommerce_rest_api/src/models/ti_wishlist_product.dart';

import 'package:woocommerce_rest_api/src/param_models/woo_product_param.dart';
import 'package:woocommerce_rest_api/src/param_models/woo_category_param.dart';
import 'package:woocommerce_rest_api/src/param_models/woo_review_param.dart';
import 'package:woocommerce_rest_api/src/param_models/woo_customer_param.dart';
import 'package:woocommerce_rest_api/src/param_models/woo_order_param.dart';
import 'package:woocommerce_rest_api/src/param_models/ti_wishlist_product_param.dart';

import 'src/utility/queryString.dart';
import 'src/models/woocommerce_rest_api_error.dart';

export 'package:woocommerce_rest_api/src/models/woo_category.dart';
export 'package:woocommerce_rest_api/src/models/woo_product.dart';
export 'package:woocommerce_rest_api/src/models/woo_review.dart';
export 'package:woocommerce_rest_api/src/models/woo_customer.dart';
export 'package:woocommerce_rest_api/src/models/woo_cart_list.dart';
export 'package:woocommerce_rest_api/src/models/woo_order.dart';
export 'package:woocommerce_rest_api/src/models/ti_wishlist.dart';
export 'package:woocommerce_rest_api/src/models/ti_wishlist_product.dart';

export 'package:woocommerce_rest_api/src/param_models/woo_product_param.dart';
export 'package:woocommerce_rest_api/src/param_models/woo_category_param.dart';
export 'package:woocommerce_rest_api/src/param_models/woo_review_param.dart';
export 'package:woocommerce_rest_api/src/param_models/woo_customer_param.dart';
export 'package:woocommerce_rest_api/src/param_models/woo_order_param.dart';
export 'package:woocommerce_rest_api/src/param_models/ti_wishlist_product_param.dart';

part 'src/product.dart';
part 'src/category.dart';
part 'src/review.dart';
part 'src/customer.dart';
part 'src/cart.dart';
part 'src/order.dart';
part 'src/wishlist.dart';
part 'src/wishlist_product.dart';

class WooCommerceRestAPI {
  String url;
  String consumerKey;
  String consumerSecret;
  String version;
  bool isHttps;

  _WooProductRepo get product {
    return _WooProductRepo(this);
  }

  _WooCategoryRepo get category {
    return _WooCategoryRepo(this);
  }

  _WooReviewRepo get review {
    return _WooReviewRepo(this);
  }

  _WooCustomerRepo get customer {
    return _WooCustomerRepo(this);
  }

  _WooCart get cart {
    return _WooCart();
  }

  _WooOrderRepo get order {
    return _WooOrderRepo(this);
  }

  _TPWishlist get wishList {
    return _TPWishlist(this);
  }

  _TPWishlistProduct get wishListProduct {
    return _TPWishlistProduct(this);
  }

  WooCommerceRestAPI(
      {@required this.url,
      @required this.consumerKey,
      @required this.consumerSecret,
      this.version = "wc/v3"}) {
    if (this.url.startsWith("https")) {
      this.isHttps = true;
    } else {
      this.isHttps = false;
    }
  }

  /// Generate a valid OAuth 1.0 URL
  ///
  /// if [isHttps] is true we just return the URL with
  /// [consumerKey] and [consumerSecret] as query parameters
  String _getOAuthURL(String requestMethod, String endpoint) {
    String consumerKey = this.consumerKey;
    String consumerSecret = this.consumerSecret;

    String token = "";
    String url = this.url + "/wp-json/$version/" + endpoint;
    bool containsQueryParams = url.contains("?");

    if (this.isHttps == true) {
      return url +
          (containsQueryParams == true
              ? "&consumer_key=" +
                  this.consumerKey +
                  "&consumer_secret=" +
                  this.consumerSecret
              : "?consumer_key=" +
                  this.consumerKey +
                  "&consumer_secret=" +
                  this.consumerSecret);
    }

    Random rand = Random();
    List<int> codeUnits = List.generate(10, (index) {
      return rand.nextInt(26) + 97;
    });

    /// Random string uniquely generated to identify each signed request
    String nonce = String.fromCharCodes(codeUnits);

    /// The timestamp allows the Service Provider to only keep nonce values for a limited time
    int timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    String parameters = "oauth_consumer_key=" +
        consumerKey +
        "&oauth_nonce=" +
        nonce +
        "&oauth_signature_method=HMAC-SHA1&oauth_timestamp=" +
        timestamp.toString() +
        "&oauth_token=" +
        token +
        "&oauth_version=1.0&";

    if (containsQueryParams == true) {
      parameters = parameters + url.split("?")[1];
    } else {
      parameters = parameters.substring(0, parameters.length - 1);
    }

    Map<dynamic, dynamic> params = QueryString.parse(parameters);
    Map<dynamic, dynamic> treeMap = new SplayTreeMap<dynamic, dynamic>();
    treeMap.addAll(params);

    String parameterString = "";

    for (var key in treeMap.keys) {
      parameterString = parameterString +
          Uri.encodeQueryComponent(key) +
          "=" +
          treeMap[key] +
          "&";
    }

    parameterString = parameterString.substring(0, parameterString.length - 1);

    String method = requestMethod;
    String baseString = method +
        "&" +
        Uri.encodeQueryComponent(
            containsQueryParams == true ? url.split("?")[0] : url) +
        "&" +
        Uri.encodeQueryComponent(parameterString);

    String signingKey = consumerSecret + "&" + token;
    crypto.Hmac hmacSha1 =
        crypto.Hmac(crypto.sha1, utf8.encode(signingKey)); // HMAC-SHA1

    /// The Signature is used by the server to verify the
    /// authenticity of the request and prevent unauthorized access.
    /// Here we use HMAC-SHA1 method.
    crypto.Digest signature = hmacSha1.convert(utf8.encode(baseString));

    String finalSignature = base64Encode(signature.bytes);

    String requestUrl = "";

    if (containsQueryParams == true) {
      requestUrl = url.split("?")[0] +
          "?" +
          parameterString +
          "&oauth_signature=" +
          Uri.encodeQueryComponent(finalSignature);
    } else {
      requestUrl = url +
          "?" +
          parameterString +
          "&oauth_signature=" +
          Uri.encodeQueryComponent(finalSignature);
    }

    return requestUrl;
  }

  Exception _handleHttpError(http.Response response) {
    switch (response.statusCode) {
      case 400:
      case 401:
      case 404:
      case 500:
        throw Exception(
            WooCommerceRestApiError.fromJson(json.decode(response.body))
                .toString());
      default:
        throw Exception(
            "An error occurred, status code: ${response.statusCode}");
    }
  }

  Future<dynamic> baseGet(String endPoint,
      {Map<String, dynamic> params: const {}}) async {
    String paramEndPoint = endPoint;

    bool containsQueryParams = paramEndPoint.contains("?");
    if (containsQueryParams)
      paramEndPoint += '&';
    else
      paramEndPoint += '?';

    for (String key in params.keys) {
      paramEndPoint += '$key=${params[key]}&';
    }

    String url = this._getOAuthURL("GET", paramEndPoint);
    try {
      final http.Response response = await http.get(url);
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      _handleHttpError(response);
    } catch (err) {
      throw err;
    }
  }

  Future<dynamic> basePost(String endPoint, Map<String, dynamic> data) async {
    String url = this._getOAuthURL("POST", endPoint);
    http.Client client = http.Client();
    http.Request request = http.Request('POST', Uri.parse(url));
    request.headers[HttpHeaders.contentTypeHeader] =
        'application/json; charset=utf-8';
    request.headers[HttpHeaders.cacheControlHeader] = "no-cache";
    request.body = json.encode(data);
    String response =
        await client.send(request).then((res) => res.stream.bytesToString());
    var dataResponse = await json.decode(response);
    if (dataResponse.containsKey('data')) {
      throw dataResponse;
    }
    return dataResponse;
  }

  Future<dynamic> basePut(String endPoint, Map<String, dynamic> data) async {
    String url = this._getOAuthURL("PUT", endPoint);
    http.Client client = http.Client();
    http.Request request = http.Request('PUT', Uri.parse(url));
    request.headers[HttpHeaders.contentTypeHeader] =
        'application/json; charset=utf-8';
    request.headers[HttpHeaders.cacheControlHeader] = "no-cache";
    request.body = json.encode(data);
    String response =
        await client.send(request).then((res) => res.stream.bytesToString());
    var dataResponse = await json.decode(response);
    if (dataResponse.containsKey('data')) {
      throw dataResponse;
    }
    return dataResponse;
  }

  Future<dynamic> baseDelete(String endPoint, {bool force = true}) async {
    String paramEndPoint = endPoint + '?force=$force';

    String url = this._getOAuthURL("DELETE", paramEndPoint);
    try {
      final http.Response response = await http.delete(url);
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      _handleHttpError(response);
    } catch (err) {
      throw err;
    }
  }
}
