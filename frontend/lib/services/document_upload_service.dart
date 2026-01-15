import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:whizz_merchants/config/app_config.dart';
import '../core/utils/app_logger.dart';
import 'app_auth_service.dart';

class DocumentUploadService {
  static String get baseUrl => AppConfig.baseUrl;
  static const uuid = Uuid();

  /// Upload business license document and return the URL
  static Future<Map<String, dynamic>> uploadBusinessLicense(
      File documentFile, {bool isRegistration = false}) async {
    return _uploadDocument(documentFile, 'business-license', isRegistration: isRegistration);
  }

  /// Upload owner identity document and return the URL
  static Future<Map<String, dynamic>> uploadOwnerIdentity(
      File documentFile, {bool isRegistration = false}) async {
    return _uploadDocument(documentFile, 'owner-identity', isRegistration: isRegistration);
  }

  /// Upload health certificate document and return the URL
  static Future<Map<String, dynamic>> uploadHealthCertificate(
      File documentFile, {bool isRegistration = false}) async {
    return _uploadDocument(documentFile, 'health-certificate', isRegistration: isRegistration);
  }

  /// Upload owner photo and return the URL
  static Future<Map<String, dynamic>> uploadOwnerPhoto(
      File documentFile, {bool isRegistration = false}) async {
    return _uploadDocument(documentFile, 'owner-photo', isRegistration: isRegistration);
  }

  /// Private method to handle document uploads
  static Future<Map<String, dynamic>> _uploadDocument(
      File documentFile, String documentType, {bool isRegistration = false}) async {
    try {
      String? token;
      Map<String, String> headers = {
        'Content-Type': 'application/json',
        'x-upload-type': documentType,
      };

      if (isRegistration) {
        // For registration uploads, don't require a token but add registration header
        headers['X-Registration-Upload'] = 'true';
        AppLogger.info(
            '🔓 Uploading ${_getDocumentDisplayName(documentType)} for registration (no auth required)');

      } else {
        // For regular uploads, require authentication
        token = await AppAuthService.getAccessToken();
        if (token == null) {
          return {
            'success': false,
            'message': 'No access token found',
          };
        }
        headers['Authorization'] = 'Bearer $token';
        AppLogger.info(
            '🔐 Uploading ${_getDocumentDisplayName(documentType)} with authentication');

      }

      // Read document file as bytes
      final documentBytes = await documentFile.readAsBytes();

      // Convert to base64
      final base64Document = base64Encode(documentBytes);

      // Determine file extension from original file
      final originalPath = documentFile.path.toLowerCase();
      String fileExtension = 'jpg';

      if (originalPath.endsWith('.png')) {
        fileExtension = 'png';
      } else if (originalPath.endsWith('.pdf')) {
        fileExtension = 'pdf';
      } else if (originalPath.endsWith('.jpg') ||
          originalPath.endsWith('.jpeg')) {
        fileExtension = 'jpg';
      }

      final fileName = '${documentType}_${uuid.v4()}.$fileExtension';

      // Create JSON request body (same format as ImageUploadService)
      final requestBody = {
        'image': base64Document,
        'filename': fileName,
      };

      // Make HTTP POST request with JSON body
      final response = await http.post(
        Uri.parse('$baseUrl/upload/$documentType'),
        headers: headers,
        body: json.encode(requestBody),
      );

      AppLogger.api('Document upload response status: ${response.statusCode}');

      AppLogger.api('Document upload response body: ${response.body}');


      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return {
            'success': true,
            'imageUrl': responseData['imageUrl'],
            'message': responseData['message'] ??
                '${_getDocumentDisplayName(documentType)} uploaded successfully',
          };
        } else {
          return {
            'success': false,
            'message': responseData['message'] ?? 'Upload failed',
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Upload failed with status: ${response.statusCode}',
        };
      }
    } catch (e) {
      AppLogger.error('Error uploading $documentType: $e');

      return {
        'success': false,
        'message':
            'Error uploading ${_getDocumentDisplayName(documentType)}: $e',
      };
    }
  }

  /// Get display name for document type
  static String _getDocumentDisplayName(String documentType) {
    switch (documentType) {
      case 'business-license':
        return 'Business License';
      case 'owner-identity':
        return 'Owner Identity';
      case 'health-certificate':
        return 'Health Certificate';
      case 'owner-photo':
        return 'Owner Photo';
      default:
        return 'Document';
    }
  }
}
