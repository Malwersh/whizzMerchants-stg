import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/business_provider.dart';
import '../providers/session_provider.dart';
import '../services/support_chat_service.dart';
import '../widgets/support_attachment_image.dart';
import '../widgets/support_category_selector.dart';

/// One authenticated branch conversation with central support only.
class SupportChatScreen extends ConsumerStatefulWidget {
  const SupportChatScreen({super.key});
  @override
  ConsumerState<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends ConsumerState<SupportChatScreen>
    with WidgetsBindingObserver {
  static const navy = Color(0xFF00296B);
  final _text = TextEditingController();
  final _scroll = ScrollController();
  final _chat = SupportChatService();
  bool _starting = false,
      _started = false,
      _uploading = false,
      _sending = false;
  String? _branchId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _branchId = ref.read(sessionProvider).businessId;
    _started = _branchId != null && _chat.hasActiveSession(_branchId!);
    _chat.addListener(_changed);
    _text.text = _chat.draft;
    _text.addListener(_draftChanged);
  }

  void _draftChanged() => _chat.setDraft(_text.text);

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _connect(
      [String category = 'human_agent', String description = 'مساعدة']) async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      final business = await ref.read(businessProvider.future);
      if (!mounted || business == null || business.id != _branchId) return;
      await _chat.startCategorizedChat(
        merchantId: business.id,
        merchantName: business.name,
        merchantEmail: business.email,
        category: category,
        categoryDescription: description,
      );
      if (mounted) {
        if (_text.text.isEmpty && _chat.draft.isNotEmpty)
          _text.text = _chat.draft;
        setState(() => _started = true);
      }
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('تعذر فتح محادثة الدعم؛ تحقق من اختيار الفرع والاتصال.')));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _started &&
        !_chat.isConnected &&
        _chat.connectionStatus != 'session_ended') _connect();
  }

  Future<void> _send() async {
    final value = _text.text.trim();
    if (value.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final queued = await _chat.sendMessage(value);
      if (!mounted) return;
      // A queued message stays pending until its server receipt arrives.
      if (queued && _text.text.trim() == value) _text.clear();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _image() async {
    if (_uploading || !_chat.isConnected) return;
    setState(() => _uploading = true);
    try {
      final image = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 85);
      if (image == null || !mounted) return;
      await _chat.sendImageMessage(File(image.path), null);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _chat.removeListener(_changed);
    _chat.flushDraft();
    _text.removeListener(_draftChanged);
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionProvider, (previous, next) {
      if (!next.isAuthenticated || next.businessId != _branchId) {
        _text.clear();
        if (mounted) Navigator.of(context).pop();
      }
    });
    final closed = _chat.connectionStatus == 'session_ended';
    return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: const Color(0xFFF4F6FA),
          appBar: AppBar(title: const Text('محادثة الدعم'), actions: [
            if (_chat.isConnected)
              IconButton(
                  tooltip: 'إنهاء المحادثة',
                  icon: const Icon(Icons.close),
                  onPressed: () async {
                    final close = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                                title: const Text('إنهاء المحادثة؟'),
                                content: const Text(
                                    'سيبقى سجل المحادثة محفوظًا لدى الدعم.'),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('رجوع')),
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('إنهاء')),
                                ]));
                    if (close == true) await _chat.endSession();
                  }),
          ]),
          body: _starting
              ? const Center(child: CircularProgressIndicator())
              : !_started
                  ? SupportCategorySelector(
                      onCategorySelected: _connect,
                      onClose: () => Navigator.pop(context))
                  : Column(children: [
                      if (_chat.isConnecting) const LinearProgressIndicator(),
                      if (_chat.error != null ||
                          (!_chat.isConnected && !_chat.isConnecting))
                        Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(children: [
                              Expanded(
                                  child: Text(_chat.error ??
                                      (closed
                                          ? 'أُغلقت المحادثة'
                                          : 'انقطع الاتصال بالدعم'))),
                              TextButton(
                                  onPressed: () => _connect(),
                                  child: Text(closed
                                      ? 'محادثة جديدة'
                                      : 'إعادة الاتصال')),
                            ])),
                      if (_chat.historyLoading) const LinearProgressIndicator(),
                      if (_chat.historyError != null)
                        TextButton(
                            onPressed: () => _chat.loadHistory(),
                            child:
                                Text('${_chat.historyError}؛ إعادة المحاولة')),
                      if (_chat.nextCursor != null)
                        TextButton(
                            onPressed: _chat.historyLoading
                                ? null
                                : () => _chat.loadHistory(older: true),
                            child: const Text('عرض الرسائل الأقدم')),
                      Expanded(
                          child: _chat.messages.isEmpty
                              ? const Center(
                                  child: Text('اكتب رسالتك لفريق الدعم'))
                              : ListView.builder(
                                  controller: _scroll,
                                  padding: const EdgeInsets.all(16),
                                  itemCount: _chat.messages.length,
                                  itemBuilder: (context, index) {
                                    final message = _chat.messages[index];
                                    final own =
                                        message.senderType == 'merchant';
                                    final unknown =
                                        message.deliveryStatus == 'unknown';
                                    return Align(
                                        alignment: own
                                            ? Alignment.centerRight
                                            : Alignment.centerLeft,
                                        child: Container(
                                            constraints: const BoxConstraints(
                                                maxWidth: 320),
                                            margin: const EdgeInsets.only(
                                                bottom: 12),
                                            padding: const EdgeInsets.all(14),
                                            decoration: BoxDecoration(
                                                color:
                                                    own ? navy : Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(18)),
                                            child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  if (message.text.isNotEmpty)
                                                    Text(message.text,
                                                        style: TextStyle(
                                                            color: own
                                                                ? Colors.white
                                                                : navy,
                                                            height: 1.5)),
                                                  if (message.isUploading)
                                                    const LinearProgressIndicator(),
                                                  if (message.attachmentId !=
                                                          null &&
                                                      message.deliveryStatus !=
                                                          'pending' &&
                                                      !unknown)
                                                    SupportAttachmentImage(
                                                        foregroundColor: own
                                                            ? Colors.white
                                                            : const Color(
                                                                0xFF00296B),
                                                        key: ValueKey(
                                                            '${_chat.sessionId}/${message.attachmentId}'),
                                                        load: () => _chat
                                                            .loadAttachment(message
                                                                .attachmentId!)),
                                                  if (own &&
                                                      message.deliveryStatus !=
                                                          null)
                                                    Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(top: 6),
                                                        child: Text(
                                                            switch (message
                                                                .deliveryStatus) {
                                                              'accepted' =>
                                                                'تم الإرسال',
                                                              'pending' =>
                                                                'جارٍ تأكيد الإرسال…',
                                                              'failed' =>
                                                                'تعذر إرسال الصورة؛ اخترها مجددًا',
                                                              _ =>
                                                                'لم يتأكد الإرسال',
                                                            },
                                                            style:
                                                                const TextStyle(
                                                                    color: Colors
                                                                        .white70,
                                                                    fontSize:
                                                                        12))),
                                                  if (unknown)
                                                    TextButton(
                                                        onPressed: !_chat
                                                                .isConnected
                                                            ? null
                                                            : () => _chat
                                                                .retryMessage(
                                                                    message
                                                                        .clientMessageId!),
                                                        child: const Text(
                                                            'إعادة المحاولة',
                                                            style: TextStyle(
                                                                color: Colors
                                                                    .white))),
                                                ])));
                                  })),
                      if (!closed)
                        SafeArea(
                            top: false,
                            child: Container(
                                color: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                child: Row(children: [
                                  IconButton(
                                      onPressed:
                                          _chat.isConnected && !_uploading
                                              ? _image
                                              : null,
                                      tooltip: 'إرفاق صورة',
                                      icon: const Icon(Icons.image_outlined,
                                          color: navy)),
                                  Expanded(
                                      child: TextField(
                                          controller: _text,
                                          maxLength: 4000,
                                          minLines: 1,
                                          maxLines: 4,
                                          decoration: const InputDecoration(
                                              hintText: 'اكتب رسالتك…',
                                              counterText: ''),
                                          onSubmitted: (_) => _send())),
                                  IconButton(
                                      onPressed:
                                          _chat.isConnected ? _send : null,
                                      tooltip: 'إرسال',
                                      icon: const Icon(Icons.send_rounded,
                                          color: navy)),
                                ]))),
                    ]),
        ));
  }
}
