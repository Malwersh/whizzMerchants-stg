import 'package:flutter/material.dart';
import '../models/whizzme_genui_component.dart';

/// WhizzMe GenUI Renderer
/// Renders dynamic AI-generated UI components
class WhizzMeGenUIRenderer extends StatelessWidget {
  final WhizzMeGenUIComponent component;
  final Function(String action, Map<String, dynamic>? data)? onAction;

  const WhizzMeGenUIRenderer({
    Key? key,
    required this.component,
    this.onAction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    switch (component.type) {
      case GenUIComponentType.text:
        return _buildTextComponent(context);
      case GenUIComponentType.card:
        return _buildCardComponent(context);
      case GenUIComponentType.quickReplies:
        return _buildQuickRepliesComponent(context);
      case GenUIComponentType.stepList:
        return _buildStepListComponent(context);
      case GenUIComponentType.warningCard:
        return _buildWarningCardComponent(context);
      case GenUIComponentType.successCard:
        return _buildSuccessCardComponent(context);
      case GenUIComponentType.buttonGroup:
        return _buildButtonGroupComponent(context);
      default:
        return _buildTextComponent(context);
    }
  }

  /// Build simple text component
  Widget _buildTextComponent(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        component.data['text'] as String? ?? '',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }

  /// Build enhanced card component with icon
  Widget _buildCardComponent(BuildContext context) {
    final text = component.data['text'] as String? ?? '';
    final icon = component.data['icon'] as IconData?;
    final color = component.data['color'] as Color? ?? Colors.blue;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Row(
                children: [
                  Icon(icon, color: color, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      component.title ?? 'Information',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (component.actions != null && component.actions!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: component.actions!
                    .map((action) => _buildActionButton(context, action))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Build quick replies component
  Widget _buildQuickRepliesComponent(BuildContext context) {
    final text = component.data['text'] as String? ?? '';
    final replies = component.data['replies'] as List<dynamic>? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: replies.map((reply) {
            return ActionChip(
              label: Text(reply as String),
              backgroundColor: Colors.white,
              side: BorderSide(color: Colors.blue.shade200),
              onPressed: () {
                onAction?.call('quick_reply', {'reply': reply});
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  /// Build step list component
  Widget _buildStepListComponent(BuildContext context) {
    final steps = component.data['steps'] as List<dynamic>? ?? [];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.format_list_numbered, color: Colors.blue.shade600),
                const SizedBox(width: 8),
                Text(
                  'Steps to Follow',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...steps.asMap().entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${entry.key + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        entry.value as String,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  /// Build warning card component
  Widget _buildWarningCardComponent(BuildContext context) {
    final text = component.data['text'] as String? ?? '';

    return Card(
      elevation: 2,
      color: Colors.orange.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange.shade700,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Important',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    text,
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

  /// Build success card component
  Widget _buildSuccessCardComponent(BuildContext context) {
    final text = component.data['text'] as String? ?? '';

    return Card(
      elevation: 2,
      color: Colors.green.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.check_circle_outline,
              color: Colors.green.shade700,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Success',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    text,
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

  /// Build button group component
  Widget _buildButtonGroupComponent(BuildContext context) {
    if (component.actions == null || component.actions!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: component.actions!
          .map((action) => _buildActionButton(context, action))
          .toList(),
    );
  }

  /// Build action button
  Widget _buildActionButton(BuildContext context, GenUIAction action) {
    if (action.isPrimary) {
      return ElevatedButton.icon(
        onPressed: () {
          onAction?.call(action.action, null);
        },
        icon: action.icon != null
            ? Icon(action.icon, size: 18)
            : const SizedBox.shrink(),
        label: Text(action.label),
        style: ElevatedButton.styleFrom(
          backgroundColor: action.color ?? Colors.blue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    } else {
      return OutlinedButton.icon(
        onPressed: () {
          onAction?.call(action.action, null);
        },
        icon: action.icon != null
            ? Icon(action.icon, size: 18)
            : const SizedBox.shrink(),
        label: Text(action.label),
        style: OutlinedButton.styleFrom(
          foregroundColor: action.color ?? Colors.blue,
          side: BorderSide(color: action.color ?? Colors.blue),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }
}
