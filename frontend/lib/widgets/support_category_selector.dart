import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

/// Support Category Selection Widget
/// Displays category options before starting chat with WhizzMe AI
class SupportCategorySelector extends StatefulWidget {
  final Function(String category, String description) onCategorySelected;
  final VoidCallback? onClose;

  const SupportCategorySelector({
    Key? key,
    required this.onCategorySelected,
    this.onClose,
  }) : super(key: key);

  @override
  State<SupportCategorySelector> createState() =>
      _SupportCategorySelectorState();
}

class _SupportCategorySelectorState extends State<SupportCategorySelector>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Category definitions will be built in build() method to use localization
  List<CategoryOption> _getCategories(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return [
      CategoryOption(
        id: 'order_management',
        title: l10n.categoryOrderManagement,
        description: l10n.categoryOrderManagementDesc,
        icon: Icons.shopping_bag_outlined,
        color: Colors.blue,
        examples: [
          l10n.categoryOrderManagementExample1,
          l10n.categoryOrderManagementExample2,
          l10n.categoryOrderManagementExample3,
        ],
      ),
      CategoryOption(
        id: 'payment_issues',
        title: l10n.categoryPaymentIssues,
        description: l10n.categoryPaymentIssuesDesc,
        icon: Icons.payment_outlined,
        color: Colors.green,
        examples: [
          l10n.categoryPaymentIssuesExample1,
          l10n.categoryPaymentIssuesExample2,
          l10n.categoryPaymentIssuesExample3,
        ],
      ),
      CategoryOption(
        id: 'account_issues',
        title: l10n.categoryAccountIssues,
        description: l10n.categoryAccountIssuesDesc,
        icon: Icons.person_outline,
        color: Colors.orange,
        examples: [
          l10n.categoryAccountIssuesExample1,
          l10n.categoryAccountIssuesExample2,
          l10n.categoryAccountIssuesExample3,
        ],
      ),
      CategoryOption(
        id: 'business_setup',
        title: l10n.categoryBusinessSetup,
        description: l10n.categoryBusinessSetupDesc,
        icon: Icons.store_outlined,
        color: Colors.purple,
        examples: [
          l10n.categoryBusinessSetupExample1,
          l10n.categoryBusinessSetupExample2,
          l10n.categoryBusinessSetupExample3,
        ],
      ),
      CategoryOption(
        id: 'technical_support',
        title: l10n.categoryTechnicalSupport,
        description: l10n.categoryTechnicalSupportDesc,
        icon: Icons.bug_report_outlined,
        color: Colors.red,
        examples: [
          l10n.categoryTechnicalSupportExample1,
          l10n.categoryTechnicalSupportExample2,
          l10n.categoryTechnicalSupportExample3,
        ],
      ),
      CategoryOption(
        id: 'human_agent',
        title: l10n.categoryHumanAgent,
        description: l10n.categoryHumanAgentDesc,
        icon: Icons.support_agent_outlined,
        color: Colors.grey,
        examples: [
          l10n.categoryHumanAgentExample1,
          l10n.categoryHumanAgentExample2,
          l10n.categoryHumanAgentExample3,
        ],
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    debugPrint(
        '🎬 [CategorySelector] initState - Creating animation controller');

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    // Add status listener for debugging
    _animationController.addStatusListener((status) {
      debugPrint('🎬 [CategorySelector] Animation status: $status');
    });

    debugPrint('🎬 [CategorySelector] Starting forward animation');
    _animationController.forward();
  }

  @override
  void dispose() {
    debugPrint(
        '🎬 [CategorySelector] dispose - Cleaning up animation controller');
    debugPrint(
        '🎬 [CategorySelector] Current animation status: ${_animationController.status}');
    debugPrint(
        '🎬 [CategorySelector] Current animation value: ${_animationController.value}');

    // Stop any ongoing animation before disposing
    _animationController.stop();
    _animationController.dispose();

    debugPrint(
        '🎬 [CategorySelector] Animation controller disposed successfully');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final categories = _getCategories(context);
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade50,
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    if (widget.onClose != null)
                      IconButton(
                        onPressed: widget.onClose,
                        icon: const Icon(Icons.close),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.supportCategoryTitle,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade800,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.supportCategorySubtitle,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Categories List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    return _buildCategoryCard(category, index);
                  },
                ),
              ),

              // Footer
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.smart_toy_outlined,
                          size: 16,
                          color: Colors.blue.shade600,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.supportPoweredBy,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.blue.shade600,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.supportAiDescription,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade500,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard(CategoryOption category, int index) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        // Fix animation intervals to ensure end <= 1.0
        // Stagger animations with smaller intervals
        final startDelay = (index * 0.08).clamp(0.0, 0.4);
        final endDelay = (startDelay + 0.5).clamp(0.0, 1.0);

        final slideAnimation = Tween<Offset>(
          begin: const Offset(0, 0.5),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _animationController,
          curve: Interval(
            startDelay,
            endDelay,
            curve: Curves.easeOutQuart,
          ),
        ));

        return SlideTransition(
          position: slideAnimation,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12.0),
            child: Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _selectCategory(category),
                child: Container(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      // Icon
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: category.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          category.icon,
                          color: category.color,
                          size: 24,
                        ),
                      ),

                      const SizedBox(width: 16),

                      // Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              category.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              category.description,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                            ),
                            if (category.examples.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children:
                                    category.examples.take(2).map((example) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      example,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Colors.grey.shade700,
                                          ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Arrow
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.grey.shade400,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _selectCategory(CategoryOption category) {
    debugPrint('🎯 [CategorySelector] Category selected: ${category.id}');
    debugPrint(
        '🎯 [CategorySelector] Animation status: ${_animationController.status}');
    debugPrint(
        '🎯 [CategorySelector] Is animating: ${_animationController.isAnimating}');
    debugPrint('🎯 [CategorySelector] Mounted: $mounted');

    // Prevent multiple taps
    if (!mounted || _animationController.isAnimating) {
      debugPrint(
          '⚠️ [CategorySelector] Selection blocked - not mounted or animating');
      return;
    }

    // Add haptic feedback
    // HapticFeedback.lightImpact();

    debugPrint('🎬 [CategorySelector] Starting reverse animation');
    // Fade out animation before callback
    _animationController.reverse().then((_) {
      debugPrint('✅ [CategorySelector] Reverse animation complete');
      if (mounted) {
        debugPrint('📞 [CategorySelector] Calling onCategorySelected callback');
        // Call the callback with selected category after animation completes
        widget.onCategorySelected(category.id, category.description);
      } else {
        debugPrint('⚠️ [CategorySelector] Widget unmounted before callback');
      }
    });
  }
}

/// Category Option Model
class CategoryOption {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final List<String> examples;

  CategoryOption({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.examples = const [],
  });
}
