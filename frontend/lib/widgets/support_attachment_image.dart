import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';

/// The loader authenticates each fetch; no public or bearer URL enters the widget.
class SupportAttachmentImage extends StatefulWidget {
  const SupportAttachmentImage({super.key, required this.load});
  final Future<Uint8List> Function() load;
  @override
  State<SupportAttachmentImage> createState() => _SupportAttachmentImageState();
}

class _SupportAttachmentImageState extends State<SupportAttachmentImage> {
  Future<Uint8List>? _image;
  void _load() {
    final future = Future.sync(widget.load);
    unawaited(future.then<void>((_) {}, onError: (Object _, StackTrace __) {}));
    setState(() {
      _image = future;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_image == null) {
      return TextButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.image_outlined),
          label: const Text('عرض الصورة'));
    }
    return FutureBuilder<Uint8List>(
        future: _image,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return TextButton(
                onPressed: _load,
                child: const Text('تعذر تحميل الصورة؛ إعادة المحاولة'));
          }
          if (!snapshot.hasData) {
            return const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator());
          }
          final bytes = snapshot.data!;
          return InkWell(
              onTap: () => showDialog<void>(
                  context: context,
                  builder: (context) => Dialog(
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                        Flexible(
                            child: InteractiveViewer(
                                child: Image.memory(bytes,
                                    errorBuilder: (_, __, ___) =>
                                        const Text('تعذر عرض الصورة')))),
                        TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('إغلاق')),
                      ]))),
              child: Image.memory(bytes,
                  width: 240,
                  height: 180,
                  fit: BoxFit.contain,
                  semanticLabel: 'صورة مرفقة بالمحادثة',
                  errorBuilder: (_, __, ___) => const Text('تعذر عرض الصورة')));
        });
  }
}
