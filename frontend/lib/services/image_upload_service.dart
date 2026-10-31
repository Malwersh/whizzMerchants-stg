import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:whizz_merchants/config/app_config.dart';
import '../core/utils/app_logger.dart';
import '../utils/token_validator.dart';
import 'app_auth_service.dart';
import 'merchant_branch_scope.dart';
import 'secure_token_storage.dart';
import 'token_refresh_service.dart';

class ImageUploadService {
  static String get baseUrl => AppConfig.baseUrl;
  static const uuid = Uuid();

  /// Returns a valid Cognito ACCESS token. The upload endpoint verifies the
  /// token via Cognito GetUser, which rejects ID tokens, so the shared
  /// AppAuthService.getAccessToken() (ID-token-first) cannot be used here.
  static Future<String?> _getCognitoAccessToken() async {
    var accessToken = await SecureTokenStorage.getAccessToken();
    if (accessToken != null &&
        accessToken.isNotEmpty &&
        !TokenValidator.isTokenExpired(accessToken)) {
      return accessToken;
    }
    await TokenRefreshService.refreshTokens();
    accessToken = await SecureTokenStorage.getAccessToken();
    if (accessToken != null &&
        accessToken.isNotEmpty &&
        !TokenValidator.isTokenExpired(accessToken)) {
      return accessToken;
    }
    return null;
  }

  /// Upload business photo and return the URL
  static Future<Map<String, dynamic>> uploadBusinessPhoto(File imageFile,
      {bool isRegistration = false, String? businessId}) async {
    try {
      String? token;
      Map<String, String> headers = {
        'Content-Type': 'application/json',
      };

      if (isRegistration) {
        // For registration uploads, don't require a token but add registration header
        headers['X-Registration-Upload'] = 'true';
        AppLogger.info(
            '🔓 Uploading business photo for registration (no auth required)');
      } else {
        // For regular uploads, require authentication
        token = await _getCognitoAccessToken();
        if (token == null) {
          return {
            'success': false,
            'message': 'No access token found',
          };
        }
        headers['Authorization'] = 'Bearer $token';
        AppLogger.info('🔐 Uploading business photo with authentication');
      }

      // Read image file as bytes
      final imageBytes = await imageFile.readAsBytes();

      // Convert to base64
      final base64Image = base64Encode(imageBytes);

      // Determine file extension from original file
      final originalPath = imageFile.path.toLowerCase();
      final fileExtension = originalPath.endsWith('.png') ? 'png' : 'jpg';
      final fileName = 'business_${uuid.v4()}.$fileExtension';

      // Create JSON request body
      final requestBody = {
        'image': base64Image,
        if (businessId != null) 'businessId': businessId,
        'filename': fileName,
      };

      // Make HTTP POST request with JSON body
      final response = await http.post(
        Uri.parse('$baseUrl/upload/business-photo'),
        headers: headers,
        body: json.encode(requestBody),
      );

      AppLogger.api(
          'Business photo upload response status: ${response.statusCode}');

      AppLogger.api('Business photo upload response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return {
            'success': true,
            'imageUrl': responseData['imageUrl'],
            'message': responseData['message'] ??
                'Business photo uploaded successfully',
          };
        } else {
          return {
            'success': false,
            'message': responseData['message'] ?? 'Upload failed',
          };
        }
      } else {
        try {
          final errorData = json.decode(response.body);
          return {
            'success': false,
            'message': errorData['message'] ?? 'Upload failed',
          };
        } catch (e) {
          return {
            'success': false,
            'message': 'Upload failed with status: ${response.statusCode}',
          };
        }
      }
    } catch (e) {
      AppLogger.error('Error uploading business photo: $e');

      return {
        'success': false,
        'message': 'Error uploading business photo: $e',
      };
    }
  }

  /// Upload image file and return the URL
  static Future<Map<String, dynamic>> uploadProductImage(File imageFile) async {
    try {
      final token = await AppAuthService.getAccessToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'No access token found',
        };
      }

      // Read image file as bytes
      final imageBytes = await imageFile.readAsBytes();

      // Convert to base64
      final base64Image = base64Encode(imageBytes);

      // Determine file extension from original file
      final originalPath = imageFile.path.toLowerCase();
      final fileExtension = originalPath.endsWith('.png') ? 'png' : 'jpg';
      final fileName = '${uuid.v4()}.$fileExtension';

      // Create JSON request body
      final requestBody = {
        'image': base64Image,
        'filename': fileName,
      };

      // Make HTTP POST request with JSON body
      final response = await http.post(
        Uri.parse('$baseUrl/upload/product-image'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(requestBody),
      );

      AppLogger.api(
          'Product image upload response status: ${response.statusCode}');

      AppLogger.api('Product image upload response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return {
            'success': true,
            'imageUrl': data['imageUrl'],
            'message': data['message'] ?? 'Image uploaded successfully',
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Failed to upload image',
          };
        }
      } else {
        try {
          final errorData = jsonDecode(response.body);
          return {
            'success': false,
            'message': errorData['message'] ?? 'Failed to upload image',
          };
        } catch (e) {
          return {
            'success': false,
            'message': 'Failed to upload image: ${response.statusCode}',
          };
        }
      }
    } catch (e) {
      AppLogger.error('Error uploading product image: $e');

      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  /// Upload image from bytes (for web compatibility)
  static Future<Map<String, dynamic>> uploadProductImageFromBytes({
    required Uint8List imageBytes,
    required String fileName,
    String? businessId,
  }) async {
    try {
      final scope = await MerchantBranchScope.capture(businessId: businessId);
      await scope.assertCurrent();
      final token = await _getCognitoAccessToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'No access token found',
        };
      }

      // Convert to base64
      final base64Image = base64Encode(imageBytes);

      // Determine file extension from file name
      final fileNameLower = fileName.toLowerCase();
      final fileExtension = fileNameLower.endsWith('.png') ? 'png' : 'jpg';
      final uniqueFileName = '${uuid.v4()}.$fileExtension';

      // Create JSON request body
      final requestBody = {
        'image':
            'data:image/${fileExtension == "png" ? "png" : "jpeg"};base64,$base64Image',
        'businessId': scope.businessId,
        'filename': uniqueFileName,
      };

      // Make HTTP POST request with JSON body
      final response = await http.post(
        scope.uri('$baseUrl/upload/product-image'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(requestBody),
      );

      AppLogger.api(
          'Product image upload response status: ${response.statusCode}');

      AppLogger.api('Product image upload response body: ${response.body}');

      await scope.assertCurrent();
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return {
            'success': true,
            'imageUrl': data['imageUrl'],
            'message': data['message'] ?? 'Image uploaded successfully',
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Failed to upload image',
          };
        }
      } else {
        try {
          final errorData = jsonDecode(response.body);
          return {
            'success': false,
            'message': errorData['message'] ?? 'Failed to upload image',
          };
        } catch (e) {
          return {
            'success': false,
            'message': 'Failed to upload image: ${response.statusCode}',
          };
        }
      }
    } catch (e) {
      AppLogger.error('Error uploading product image from bytes: $e');

      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  /// Delete uploaded image
  static Future<Map<String, dynamic>> deleteProductImage(
      String imageUrl) async {
    try {
      final token = await AppAuthService.getAccessToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'No access token found',
        };
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/upload/product-image'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'imageUrl': imageUrl}),
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Image deleted successfully',
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to delete image',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }
}
