import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../services/secure_token_storage.dart';
import '../../core/utils/app_logger.dart';

/// Debug screen to view session and token information
/// ONLY USE IN DEBUG MODE - Remove or protect in production
class SessionDebugScreen extends StatefulWidget {
  const SessionDebugScreen({super.key});

  @override
  State<SessionDebugScreen> createState() => _SessionDebugScreenState();
}

class _SessionDebugScreenState extends State<SessionDebugScreen> {
  Map<String, dynamic> _sessionInfo = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessionInfo();
  }

  Future<void> _loadSessionInfo() async {
    setState(() => _isLoading = true);

    try {
      final info = await SecureTokenStorage.getSessionInfo();
      setState(() {
        _sessionInfo = info;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('Error loading session info: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testTokenValidation() async {
    try {
      final isValid = await SecureTokenStorage.hasValidSession();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isValid ? '✅ Session is VALID' : '❌ Session is INVALID',
            ),
            backgroundColor: isValid ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Error testing token validation: $e');
    }
  }

  Future<void> _clearSession() async {
    try {
      await SecureTokenStorage.clearAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🧹 Session cleared successfully'),
            backgroundColor: Colors.orange,
          ),
        );
        _loadSessionInfo();
      }
    } catch (e) {
      AppLogger.error('Error clearing session: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return const SizedBox.shrink();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Debug'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSessionInfo,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildSessionStatus(),
                  const SizedBox(height: 24),
                  _buildTokenInfo(),
                  const SizedBox(height: 24),
                  _buildBusinessInfo(),
                  const SizedBox(height: 24),
                  _buildTimestamps(),
                  const SizedBox(height: 24),
                  _buildActionButtons(),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    final isValid = _sessionInfo['hasValidSession'] == true;
    return Card(
      color: isValid ? Colors.green.shade50 : Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              isValid ? Icons.check_circle : Icons.error,
              color: isValid ? Colors.green : Colors.red,
              size: 48,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isValid ? 'Session Valid' : 'Session Invalid',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isValid
                          ? Colors.green.shade900
                          : Colors.red.shade900,
                    ),
                  ),
                  Text(
                    isValid ? 'User is authenticated' : 'User needs to login',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionStatus() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Session Status',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              'Has Valid Session',
              _sessionInfo['hasValidSession'] == true ? 'Yes ✅' : 'No ❌',
              _sessionInfo['hasValidSession'] == true,
            ),
            _buildInfoRow(
              'Tokens Expired',
              _sessionInfo['isExpired'] == true ? 'Yes ⏰' : 'No ✅',
              _sessionInfo['isExpired'] != true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTokenInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Token Information',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              'Access Token',
              _sessionInfo['hasAccessToken'] == true
                  ? 'Present ✅'
                  : 'Missing ❌',
              _sessionInfo['hasAccessToken'] == true,
            ),
            _buildInfoRow(
              'ID Token',
              _sessionInfo['hasIdToken'] == true ? 'Present ✅' : 'Missing ❌',
              _sessionInfo['hasIdToken'] == true,
            ),
            _buildInfoRow(
              'Refresh Token',
              _sessionInfo['hasRefreshToken'] == true
                  ? 'Present ✅'
                  : 'Missing ❌',
              _sessionInfo['hasRefreshToken'] == true,
            ),
            if (_sessionInfo['tokenExpiry'] != null) ...[
              const Divider(),
              _buildInfoRow(
                'Token Expiry',
                _formatDateTime(_sessionInfo['tokenExpiry']),
                !(_sessionInfo['isExpired'] == true),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Business Information',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              'Business ID',
              _sessionInfo['businessId'] ?? 'Not set ❌',
              _sessionInfo['businessId'] != null,
            ),
            _buildInfoRow(
              'User ID',
              _sessionInfo['userId'] ?? 'Not set',
              _sessionInfo['userId'] != null,
            ),
            _buildInfoRow(
              'Email',
              _sessionInfo['email'] ?? 'Not set',
              _sessionInfo['email'] != null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimestamps() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Activity Timestamps',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              'Last Activity',
              _sessionInfo['lastActivity'] != null
                  ? _formatDateTime(_sessionInfo['lastActivity'])
                  : 'No recent activity',
              _sessionInfo['lastActivity'] != null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: _testTokenValidation,
          icon: const Icon(Icons.verified),
          label: const Text('Test Token Validation'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.all(16),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _loadSessionInfo,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh Session Info'),
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Clear Session?'),
                content: const Text(
                  'This will clear all stored tokens and session data. You will need to login again.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Clear'),
                  ),
                ],
              ),
            );

            if (confirm == true) {
              _clearSession();
            }
          },
          icon: const Icon(Icons.delete_forever),
          label: const Text('Clear Session (Logout)'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.all(16),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, bool isGood) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                color: isGood ? Colors.green.shade700 : Colors.red.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(String? isoString) {
    if (isoString == null) return 'N/A';
    try {
      final dateTime = DateTime.parse(isoString);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes} min ago';
      } else if (difference.inDays < 1) {
        return '${difference.inHours} hours ago';
      } else {
        return '${difference.inDays} days ago';
      }
    } catch (e) {
      return isoString;
    }
  }
}
