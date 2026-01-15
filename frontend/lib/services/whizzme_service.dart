import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/whizzme_genui_component.dart'; // GenUI support
import '../config/app_config.dart';

/// WhizzMe AI Agent Service
/// Handles AI-first chat initialization and handoff to human agents
/// NOW WITH GENUI - Dynamic UI Generation
class WhizzMeService extends ChangeNotifier {
  // Singleton instance
  static final WhizzMeService _instance = WhizzMeService._internal();
  factory WhizzMeService() => _instance;
  WhizzMeService._internal();

  // Configuration - WhizzMe API (must be provided via dart-define)
  static String get aiEndpoint => AppConfig.whizzMeApiUrl;
  static const bool USE_AWS_BEDROCK = true; // Always use real AWS Bedrock API

  // Knowledge Base Categories
  static const Map<String, List<String>> KNOWLEDGE_BASE = {
    'account_issues': [
      'login problems',
      'password reset',
      'account verification',
      'profile updates',
      'email changes'
    ],
    'order_management': [
      'new orders',
      'order status',
      'order cancellation',
      'refunds',
      'order history'
    ],
    'payment_issues': [
      'payment methods',
      'transaction failures',
      'refund status',
      'payout delays',
      'commission questions'
    ],
    'business_setup': [
      'menu management',
      'store hours',
      'location settings',
      'business verification',
      'store closure'
    ],
    'technical_support': [
      'app crashes',
      'notification issues',
      'sync problems',
      'performance issues',
      'feature requests'
    ]
  };

  // State
  bool _isEnabled = true;
  int _conversationCount = 0;
  String? _currentTopic;
  List<String> _conversationHistory = [];
  bool _escalatedToHuman = false;

  // GenUI State
  List<WhizzMeGenUIComponent> _genUIComponents = [];
  bool _genUIEnabled = true;

  // Getters
  bool get isEnabled => _isEnabled;
  bool get hasEscalated => _escalatedToHuman;
  String? get currentTopic => _currentTopic;
  List<WhizzMeGenUIComponent> get genUIComponents => _genUIComponents;
  bool get isGenUIEnabled => _genUIEnabled;

  /// Initialize WhizzMe for a new chat session
  Future<String?> initializeChat({
    required String merchantId,
    required String merchantName,
    String? businessType,
    Map<String, dynamic>? context,
  }) async {
    try {
      _conversationCount = 0;
      _escalatedToHuman = false;
      _conversationHistory.clear();
      _currentTopic = null;

      // Generate contextual greeting based on business data
      final greeting = await _generateContextualGreeting(
        merchantName: merchantName,
        businessType: businessType,
        context: context,
      );

      _conversationHistory.add('WhizzMe: $greeting');
      notifyListeners();

      return greeting;
    } catch (error) {
      debugPrint('❌ WhizzMe initialization error: $error');
      return _getFallbackGreeting(merchantName);
    }
  }

  /// Process user message and generate AI response
  Future<WhizzMeResponse> processMessage({
    required String message,
    required String merchantId,
    required String sessionId,
    Map<String, dynamic>? context,
  }) async {
    try {
      _conversationHistory.add('Merchant: $message');
      _conversationCount++;

      // Check if user wants to talk to human
      if (_shouldEscalateToHuman(message)) {
        _escalatedToHuman = true;
        return WhizzMeResponse(
          message:
              "I understand you'd like to speak with a human agent. Let me connect you to our support team right away! 👥",
          escalateToHuman: true,
          confidence: 1.0,
          category: 'human_escalation',
        );
      }

      // Check if issue seems resolved
      if (_isResolutionMessage(message)) {
        return WhizzMeResponse(
          message:
              "Great! I'm happy I could help resolve your issue. Is there anything else I can assist you with today? 😊",
          confidence: 0.9,
          category: 'resolution',
          suggestEndSession: true,
        );
      }

      // Analyze message and get AI response
      var response = await _getAIResponse(
        message: message,
        merchantId: merchantId,
        sessionId: sessionId,
        context: context,
      );

      _conversationHistory.add('WhizzMe: ${response.message}');

      // Auto-escalate after multiple exchanges if not resolved
      if (_conversationCount >= 4 && !response.suggestEndSession) {
        // Create new response with escalation
        response = WhizzMeResponse(
          message:
              "${response.message}\n\nI'd like to connect you with one of our human agents who can provide more detailed assistance. 👨‍💼",
          confidence: response.confidence,
          category: response.category,
          escalateToHuman: true,
          suggestEndSession: response.suggestEndSession,
        );
      }

      notifyListeners();
      return response;
    } catch (error) {
      debugPrint('❌ WhizzMe processing error: $error');
      return WhizzMeResponse(
        message:
            "I'm having trouble processing your request right now. Let me connect you with a human agent who can help! 🔄",
        escalateToHuman: true,
        confidence: 0.0,
        category: 'error_fallback',
      );
    }
  }

  /// Generate contextual greeting based on merchant data and selected category
  Future<String> _generateContextualGreeting({
    required String merchantName,
    String? businessType,
    Map<String, dynamic>? context,
  }) async {
    final timeOfDay = _getTimeOfDayGreeting();
    final selectedCategory = context?['selectedCategory'] as String?;
    final categoryDescription = context?['categoryDescription'] as String?;

    String categorySpecificIntro = '';
    if (selectedCategory != null && categoryDescription != null) {
      // Generate category-specific greeting
      switch (selectedCategory) {
        case 'order_management':
          categorySpecificIntro =
              "I see you need help with orders and fulfillment. I'm here to help you manage new orders, track status, handle cancellations, and process refunds! 📋";
          break;
        case 'payment_issues':
          categorySpecificIntro =
              "I can help you with payment and payout questions. Whether it's payment methods, transaction issues, or payout delays, I've got you covered! 💰";
          break;
        case 'account_issues':
          categorySpecificIntro =
              "I'll assist you with account and login related issues. From password resets to account verification, let's get you sorted! 🔐";
          break;
        case 'business_setup':
          categorySpecificIntro =
              "I'm here to help with your menu and store setup. Menu management, store hours, and business settings - I can guide you through it all! 🏪";
          break;
        case 'technical_support':
          categorySpecificIntro =
              "I'll help you resolve technical issues. App crashes, notifications, sync problems - let's troubleshoot together! 🔧";
          break;
        default:
          categorySpecificIntro =
              "I'm here to help with your WhizzBusiness account. Whatever you need assistance with, let's work on it together! 🚀";
      }
    }

    if (categorySpecificIntro.isNotEmpty) {
      return "$timeOfDay I'm WhizzMe, your AI assistant! 🤖\n\n"
          "$categorySpecificIntro\n\n"
          "What specific issue can I help you resolve today, $merchantName?";
    }

    // Fallback generic greeting
    final businessContext =
        businessType != null ? ' for your ${businessType}' : '';
    return "$timeOfDay I'm WhizzMe, your AI assistant! 🤖\n\n"
        "I'm here to help you with anything related to your WhizzBusiness account$businessContext. "
        "I can assist with orders, payments, account settings, and more!\n\n"
        "What can I help you with today, $merchantName?";
  }

  /// Get AI response from backend service
  Future<WhizzMeResponse> _getAIResponse({
    required String message,
    required String merchantId,
    required String sessionId,
    Map<String, dynamic>? context,
  }) async {
    try {
      // Categorize the message
      final category = _categorizeMessage(message);

      // Check for quick resolution first
      final quickAnswer = _getQuickAnswer(message, category);
      if (quickAnswer != null) {
        return WhizzMeResponse(
          message: quickAnswer,
          confidence: 0.8,
          category: category,
        );
      }

      // Call AI backend if available
      if (_isEnabled) {
        try {
          final aiResponse = await _callAIBackend(
            message: message,
            merchantId: merchantId,
            sessionId: sessionId,
            category: category,
            context: context,
          );

          if (aiResponse != null) {
            // Generate GenUI component from AI response
            if (_genUIEnabled) {
              final genUIComponent = WhizzMeGenUIComponent.fromAIResponse(
                aiResponse.message,
                category,
              );
              addGenUIComponent(genUIComponent);
            }

            return aiResponse;
          }
        } catch (e) {
          debugPrint('⚠️ AI backend error, using knowledge base: $e');
        }
      }

      // Fallback to knowledge base response
      return _getKnowledgeBaseResponse(message, category);
    } catch (error) {
      debugPrint('❌ Error getting AI response: $error');
      return WhizzMeResponse(
        message:
            "I'm having trouble right now. Let me connect you with a human agent! 🔄",
        escalateToHuman: true,
        confidence: 0.0,
        category: 'error',
      );
    }
  }

  /// Call AI backend service
  Future<WhizzMeResponse?> _callAIBackend({
    required String message,
    required String merchantId,
    required String sessionId,
    required String category,
    Map<String, dynamic>? context,
  }) async {
    try {
      final requestBody = {
        'message': message,
        'userType': 'merchant',
        'sessionId': sessionId,
        'conversationHistory': _conversationHistory.take(10).toList(),
        'metadata': {
          'merchantId': merchantId,
          'category': category,
          'conversationCount': _conversationCount,
          'businessContext': context,
        }
      };

      final response = await http
          .post(
            Uri.parse(aiEndpoint),
            headers: {
              'Content-Type': 'application/json',
            },
            body: json.encode(requestBody),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return WhizzMeResponse(
            message: data['suggestion'] ?? 'I can help you with that!',
            confidence: (data['confidence'] ?? 0.7).toDouble(),
            category: category,
          );
        }
      }

      return null;
    } catch (error) {
      debugPrint('❌ AI backend call failed: $error');
      return null;
    }
  }

  /// Categorize user message
  String _categorizeMessage(String message) {
    final lowerMessage = message.toLowerCase();

    for (final category in KNOWLEDGE_BASE.keys) {
      final keywords = KNOWLEDGE_BASE[category]!;
      for (final keyword in keywords) {
        if (lowerMessage.contains(keyword.toLowerCase())) {
          _currentTopic = category;
          return category;
        }
      }
    }

    return 'general';
  }

  /// Get quick answer for common questions
  String? _getQuickAnswer(String message, String category) {
    final lowerMessage = message.toLowerCase();

    // Quick answers for common issues
    if (lowerMessage.contains('new order') ||
        lowerMessage.contains('order notification')) {
      return "To manage new orders:\n\n"
          "1. Check your Orders tab 📋\n"
          "2. You'll get push notifications for new orders\n"
          "3. Accept/reject orders within the time limit\n\n"
          "Is there a specific issue with order notifications?";
    }

    if (lowerMessage.contains('payout') || lowerMessage.contains('payment')) {
      return "For payment and payout questions:\n\n"
          "💰 Payouts are processed weekly\n"
          "📊 Check your Earnings tab for details\n"
          "🏦 Ensure your bank details are updated\n\n"
          "What specific payment issue can I help with?";
    }

    if (lowerMessage.contains('store hours') ||
        lowerMessage.contains('opening hours')) {
      return "To update your store hours:\n\n"
          "1. Go to Settings ⚙️\n"
          "2. Select 'Business Hours'\n"
          "3. Set your daily hours\n"
          "4. Use 'Closed' for off days\n\n"
          "Need help with specific hours setup?";
    }

    return null;
  }

  /// Get knowledge base response
  WhizzMeResponse _getKnowledgeBaseResponse(String message, String category) {
    final responses = {
      'account_issues':
          "I can help with account-related issues! Here are common solutions:\n\n"
              "🔐 Login problems: Try password reset\n"
              "📧 Email issues: Check spam folder\n"
              "✅ Verification: Check for pending documents\n\n"
              "What specific account issue are you facing?",
      'order_management':
          "For order management, here's what I can help with:\n\n"
              "📋 New orders: Check Orders tab\n"
              "🔄 Order status: Track in real-time\n"
              "❌ Cancellations: Contact customer first\n\n"
              "Which order topic do you need help with?",
      'payment_issues': "Payment questions? I've got you covered:\n\n"
          "💳 Payment methods: Update in Settings\n"
          "🔄 Failed transactions: Check connection\n"
          "💰 Payouts: Processed weekly to your account\n\n"
          "What payment issue can I resolve for you?",
      'business_setup': "Business setup assistance:\n\n"
          "📝 Menu updates: Use Menu Management\n"
          "🕒 Store hours: Set in Business Settings\n"
          "📍 Location: Verify address accuracy\n\n"
          "Which setup area needs attention?",
      'technical_support': "Technical issues? Let me help:\n\n"
          "📱 App problems: Try restart/update\n"
          "🔔 Notifications: Check settings\n"
          "🔄 Sync issues: Check internet connection\n\n"
          "What technical issue are you experiencing?",
    };

    return WhizzMeResponse(
      message: responses[category] ??
          "I understand you need help with that! Let me connect you with our support team for personalized assistance. 👥",
      confidence: category != 'general' ? 0.7 : 0.3,
      category: category,
      escalateToHuman: category == 'general',
    );
  }

  /// Check if should escalate to human
  bool _shouldEscalateToHuman(String message) {
    final lowerMessage = message.toLowerCase();
    final escalationPhrases = [
      'human agent',
      'real person',
      'speak to someone',
      'talk to human',
      'human support',
      'customer service',
      'representative',
      'agent',
      'this is not helping',
      'not working',
      'still problem',
      'frustrated',
      'angry',
      'escalate',
      'manager',
      'supervisor'
    ];

    return escalationPhrases.any((phrase) => lowerMessage.contains(phrase));
  }

  /// Check if message indicates resolution
  bool _isResolutionMessage(String message) {
    final lowerMessage = message.toLowerCase();
    final resolutionPhrases = [
      'thank you',
      'thanks',
      'solved',
      'fixed',
      'resolved',
      'working now',
      'great',
      'perfect',
      'excellent',
      'all good',
      'problem solved'
    ];

    return resolutionPhrases.any((phrase) => lowerMessage.contains(phrase));
  }

  /// Get time-appropriate greeting
  String _getTimeOfDayGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good morning! ☀️";
    if (hour < 17) return "Good afternoon! 🌤️";
    return "Good evening! 🌙";
  }

  /// Get fallback greeting
  String _getFallbackGreeting(String merchantName) {
    return "Hello $merchantName! 👋\n\n"
        "I'm WhizzMe, your AI assistant. I'm here to help with your WhizzBusiness account, "
        "orders, payments, and any other questions you might have!\n\n"
        "How can I assist you today?";
  }

  /// Reset conversation state
  void resetConversation() {
    _conversationCount = 0;
    _escalatedToHuman = false;
    _conversationHistory.clear();
    _currentTopic = null;
    notifyListeners();
  }

  /// Enable/disable AI service
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    notifyListeners();
  }

  /// Enable/Disable GenUI
  void setGenUIEnabled(bool enabled) {
    _genUIEnabled = enabled;
    notifyListeners();
  }

  /// Add GenUI component
  void addGenUIComponent(WhizzMeGenUIComponent component) {
    _genUIComponents.add(component);
    notifyListeners();
  }

  /// Clear GenUI components
  void clearGenUIComponents() {
    _genUIComponents.clear();
    notifyListeners();
  }
}

/// WhizzMe Response Model
class WhizzMeResponse {
  final String message;
  final double confidence;
  final String category;
  final bool escalateToHuman;
  final bool suggestEndSession;

  WhizzMeResponse({
    required this.message,
    required this.confidence,
    required this.category,
    this.escalateToHuman = false,
    this.suggestEndSession = false,
  });

  bool get shouldEscalate => escalateToHuman || confidence < 0.3;
  bool get isHighConfidence => confidence > 0.7;
}
