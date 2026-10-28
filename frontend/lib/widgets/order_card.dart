import 'merchant_handover_button.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/order.dart';
import '../utils/responsive_helper.dart';
import '../core/design_system/design_system.dart';
import '../l10n/app_localizations.dart';
import 'circular_order_timer.dart';

String formatOrderCardIqd(double amount) =>
    '${NumberFormat('#,##0.###', 'en').format(amount)} د.ع';

class OrderCard extends ConsumerWidget {
  final Order order;
  final VoidCallback? onTap;
  final VoidCallback? onHandoverRecorded;
  final String? actionLabel;
  final bool Function(OrderStatus)? canUpdateStatus;
  bool allows(OrderStatus status) => canUpdateStatus?.call(status) ?? true;
  final Function(String, OrderStatus) onOrderUpdated;

  const OrderCard({
    super.key,
    required this.order,
    this.onTap,
    this.onHandoverRecorded,
    this.actionLabel,
    this.canUpdateStatus,
    required this.onOrderUpdated,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile = ResponsiveHelper.isMobile(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.all(isMobile ? GoldenRatio.md : GoldenRatio.lg),
        decoration: BoxDecoration(
          color: WhizzColors.surface,
          borderRadius: BorderRadius.circular(GoldenRatio.lg),
          border: Border.all(
            color: WhizzColors.borderPrimary,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: WhizzColors.shadow,
              spreadRadius: 2,
              blurRadius: GoldenRatio.md,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(GoldenRatio.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                      child: Row(
                    children: [
                      Expanded(
                          child: Text(
                        '#${order.displayOrderNumber}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TypographySystem.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF00296B),
                        ),
                      )),
                      // Add circular timer for pending orders
                      if (order.status == OrderStatus.pending &&
                          (allows(OrderStatus.cancelled) ||
                              allows(OrderStatus.confirmed))) ...[
                        SizedBox(width: GoldenRatio.md),
                        CircularOrderTimer(
                          orderId: order.id,
                          createdAt: order.createdAt,
                          totalMinutes: 5,
                          deadlineAt: order.merchantAcceptanceDeadlineAt,
                          size: 40.0,
                          onTimeUp: () {
                            // Handle timeout - visual indication
                            debugPrint('⏰ Order ${order.id} timed out!');
                          },
                        ),
                      ],
                    ],
                  )),
                  SizedBox(width: GoldenRatio.sm),
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: GoldenRatio.lg, vertical: GoldenRatio.xs),
                    decoration: BoxDecoration(
                      color: _getStatusColor(order.status),
                      borderRadius: BorderRadius.circular(GoldenRatio.xl),
                    ),
                    child: Text(
                      _getStatusText(context, order.status),
                      style: TypographySystem.labelMedium.copyWith(
                        color: WhizzColors.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: GoldenRatio.lg),

              if (actionLabel != null && onTap != null)
                OutlinedButton(onPressed: onTap, child: Text(actionLabel!)),
              if (order.driverSearchUnavailable)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                      'تعذر العثور على سائق. الطلب ما زال قائمًا ويحتاج متابعة من المنصة.'),
                ),
              if (order.driverReplacementSearch &&
                  !order.driverSearchUnavailable)
                const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                        'الطلب جاهز لدى المطعم. نبحث عن سائق بديل بعد اعتذار السائق السابق.')),
              // Customer Info
              Row(
                children: [
                  Icon(Icons.person,
                      size: GoldenRatio.lg,
                      color: WhizzColors.onSurfaceVariant),
                  SizedBox(width: GoldenRatio.md),
                  Expanded(
                    child: Text(
                      order.customerName,
                      style: TypographySystem.bodyMedium.copyWith(
                        fontWeight: FontWeight.w500,
                        color: WhizzColors.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: GoldenRatio.md),

              // Phone
              if (order.customerPhone?.isNotEmpty ?? false) ...[
                Row(
                  children: [
                    Icon(Icons.phone,
                        size: GoldenRatio.lg,
                        color: WhizzColors.onSurfaceVariant),
                    SizedBox(width: GoldenRatio.md),
                    Text(
                      order.customerPhone!,
                      style: TypographySystem.bodyMedium.copyWith(
                        color: WhizzColors.onSurface,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: GoldenRatio.md),
              ],

              // Items
              Container(
                padding: EdgeInsets.all(GoldenRatio.lg),
                decoration: BoxDecoration(
                  color: WhizzColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(GoldenRatio.md),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الأصناف (${order.items.fold<int>(0, (n, i) => n + i.quantity)} قطعة)',
                      style: TypographySystem.titleSmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: WhizzColors.primary,
                      ),
                    ),
                    SizedBox(height: GoldenRatio.md),
                    ...order.items.take(3).map((item) => Padding(
                          padding:
                              EdgeInsets.symmetric(vertical: GoldenRatio.xs),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${item.quantity} × ${item.name}${item.modifiers.isNotEmpty ? '\n${item.modifiers.join('، ')}' : ''}${item.notes?.isNotEmpty == true ? '\nملاحظة: ${item.notes}' : ''}',
                                  style: TypographySystem.bodySmall.copyWith(
                                    color: WhizzColors.onSurface,
                                  ),
                                ),
                              ),
                              Text(
                                formatOrderCardIqd(item.price * item.quantity),
                                style: TypographySystem.bodySmall.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: WhizzColors.onSurface,
                                ),
                              ),
                            ],
                          ),
                        )),
                    if (order.items.length > 3)
                      ExpansionTile(
                          title: Text(
                              'عرض بقية الأصناف (${order.items.length - 3})'),
                          children: order.items
                              .skip(3)
                              .map((item) => ListTile(
                                  title:
                                      Text('${item.quantity} × ${item.name}'),
                                  subtitle: Text([
                                    if (item.modifiers.isNotEmpty)
                                      item.modifiers.join('، '),
                                    if (item.notes?.isNotEmpty == true)
                                      item.notes!
                                  ].join('\n')),
                                  trailing: Text(formatOrderCardIqd(
                                      item.price * item.quantity))))
                              .toList()),
                  ],
                ),
              ),
              SizedBox(height: GoldenRatio.lg),

              // Total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'الإجمالي',
                    style: TypographySystem.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF00296B),
                    ),
                  ),
                  Text(
                    formatOrderCardIqd(order.totalAmount),
                    style: TypographySystem.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: const Color(0xFF00296B),
                    ),
                  ),
                ],
              ),
              SizedBox(height: GoldenRatio.lg),

              Row(children: [
                const Icon(Icons.payments_outlined, size: 18),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(['cash', 'cod']
                            .contains(order.paymentMethod.toLowerCase())
                        ? 'الدفع نقدًا عند الاستلام'
                        : 'طريقة الدفع: ${order.paymentMethod}'))
              ]),
              if (order.notes?.isNotEmpty == true)
                Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('ملاحظات الطلب: ${order.notes}')),
              if (order.deliveryInstructions?.isNotEmpty == true)
                Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child:
                        Text('تعليمات التوصيل: ${order.deliveryInstructions}')),
              const SizedBox(height: 8),
              // Time
              Text(
                'Ordered ${_formatTime(order.createdAt)}',
                style: TypographySystem.bodySmall.copyWith(
                  color: WhizzColors.onSurfaceVariant,
                ),
              ),

              // Action Buttons - MERCHANT SCOPE ONLY (pending → confirmed → preparing → ready)
              if (order.status == OrderStatus.pending &&
                  (allows(OrderStatus.cancelled) ||
                      allows(OrderStatus.confirmed))) ...[
                SizedBox(height: GoldenRatio.xl),
                Row(
                  children: [
                    if (allows(OrderStatus.cancelled))
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              onOrderUpdated(order.id, OrderStatus.cancelled),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: WhizzColors.error,
                            side: BorderSide(color: WhizzColors.error),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(GoldenRatio.md),
                            ),
                            padding:
                                EdgeInsets.symmetric(vertical: GoldenRatio.lg),
                          ),
                          child: Text(
                            'رفض',
                            style: TypographySystem.labelLarge.copyWith(
                              color: WhizzColors.error,
                            ),
                          ),
                        ),
                      ),
                    if (allows(OrderStatus.cancelled) &&
                        allows(OrderStatus.confirmed))
                      SizedBox(width: GoldenRatio.lg),
                    if (allows(OrderStatus.confirmed))
                      Expanded(
                        child: ElevatedButton(
                          onPressed: order.shouldAutoReject()
                              ? null
                              : () => onOrderUpdated(
                                  order.id, OrderStatus.confirmed),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: WhizzColors.primary,
                            foregroundColor: WhizzColors.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(GoldenRatio.md),
                            ),
                            padding:
                                EdgeInsets.symmetric(vertical: GoldenRatio.lg),
                          ),
                          child: Text(
                            'قبول',
                            style: TypographySystem.labelLarge.copyWith(
                              color: WhizzColors.onPrimary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ] else if (order.status == OrderStatus.confirmed &&
                  allows(OrderStatus.preparing)) ...[
                SizedBox(height: GoldenRatio.xl),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () =>
                        onOrderUpdated(order.id, OrderStatus.preparing),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: WhizzColors.secondary,
                      foregroundColor: WhizzColors.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(GoldenRatio.md),
                      ),
                      padding: EdgeInsets.symmetric(vertical: GoldenRatio.lg),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.restaurant, size: 18),
                        SizedBox(width: GoldenRatio.md),
                        Text(
                          'Start Preparing',
                          style: TypographySystem.labelLarge.copyWith(
                            color: WhizzColors.onPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else if (order.status == OrderStatus.preparing &&
                  allows(OrderStatus.readyForPickup)) ...[
                SizedBox(height: GoldenRatio.xl),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () =>
                        onOrderUpdated(order.id, OrderStatus.readyForPickup),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: WhizzColors.success,
                      foregroundColor: WhizzColors.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(GoldenRatio.md),
                      ),
                      padding: EdgeInsets.symmetric(vertical: GoldenRatio.lg),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, size: 18),
                        SizedBox(width: GoldenRatio.md),
                        Text(
                          'Mark Ready for Pickup',
                          style: TypographySystem.labelLarge.copyWith(
                            color: WhizzColors.onPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else if (order.status == OrderStatus.ready ||
                  order.status == OrderStatus.readyForPickup) ...[
                SizedBox(height: GoldenRatio.xl),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(GoldenRatio.lg),
                  decoration: BoxDecoration(
                    color: WhizzColors.successContainer,
                    borderRadius: BorderRadius.circular(GoldenRatio.md),
                    border: Border.all(
                      color: WhizzColors.borderPrimary,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // عنوان الحالة
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.delivery_dining,
                              color: WhizzColors.success, size: 20),
                          SizedBox(width: GoldenRatio.md),
                          Text(
                            'جاهز للاستلام',
                            style: TypographySystem.labelLarge.copyWith(
                              color: WhizzColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              if (canUpdateStatus == null)
                MerchantHandoverButton(
                    key: ValueKey(
                        'handover-${order.id}-${order.financialAssignment?['attempt']}'),
                    order: order,
                    onRecorded: onHandoverRecorded),

              // 🚗 عرض معلومات السائق في جميع حالات التوصيل (ready → delivered)
              if (order.driverId != null &&
                  order.driverName != null &&
                  _shouldShowDriverInfo(order.status)) ...[
                SizedBox(height: GoldenRatio.lg),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(GoldenRatio.lg),
                  decoration: BoxDecoration(
                    color: WhizzColors.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(GoldenRatio.md),
                    border: Border.all(
                      color: WhizzColors.primary.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badge: تم تعيين سائق
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: GoldenRatio.md,
                          vertical: GoldenRatio.sm,
                        ),
                        decoration: BoxDecoration(
                          color: WhizzColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(GoldenRatio.sm),
                          border: Border.all(
                            color: WhizzColors.primary,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.person_pin_circle,
                              color: WhizzColors.primary,
                              size: 18,
                            ),
                            SizedBox(width: GoldenRatio.sm),
                            Text(
                              'معلومات السائق',
                              style: TypographySystem.labelMedium.copyWith(
                                color: WhizzColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: GoldenRatio.md),

                      // معلومات السائق
                      _buildDriverInfoRow(
                        icon: Icons.person,
                        label: 'السائق',
                        value: order.driverName!,
                      ),

                      if (order.vehicleType != null)
                        _buildDriverInfoRow(
                          icon: Icons.directions_car,
                          label: 'نوع المركبة',
                          value: order.vehicleType!,
                        ),

                      if (order.vehiclePlate != null)
                        _buildDriverInfoRow(
                          icon: Icons.pin,
                          label: 'رقم اللوحة',
                          value: order.vehiclePlate!,
                        ),

                      if (order.driverPhone != null)
                        _buildDriverInfoRow(
                          icon: Icons.phone,
                          label: 'رقم الهاتف',
                          value: order.driverPhone!,
                        ),

                      // وقت التعيين
                      if (order.driverAssignedAt != null) ...[
                        SizedBox(height: GoldenRatio.sm),
                        Text(
                          'تم التعيين: ${_formatTime(order.driverAssignedAt!)}',
                          style: TypographySystem.bodySmall.copyWith(
                            color: WhizzColors.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              // DELIVERY STATES (onTheWay, delivered) - READ-ONLY for merchant
              if (order.status == OrderStatus.onTheWay) ...[
                SizedBox(height: GoldenRatio.xl),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(GoldenRatio.lg),
                  decoration: BoxDecoration(
                    color: WhizzColors.primaryContainer,
                    borderRadius: BorderRadius.circular(GoldenRatio.md),
                    border: Border.all(
                      color: WhizzColors.borderPrimary,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.local_shipping,
                          color: WhizzColors.primary, size: 20),
                      SizedBox(width: GoldenRatio.md),
                      Text(
                        'Out for Delivery',
                        style: TypographySystem.labelLarge.copyWith(
                          color: WhizzColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: GoldenRatio.md),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(GoldenRatio.md),
                  child: Text(
                    'Driver is on the way to customer',
                    style: TypographySystem.bodySmall.copyWith(
                      color: WhizzColors.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              if (order.status == OrderStatus.delivered) ...[
                SizedBox(height: GoldenRatio.xl),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(GoldenRatio.lg),
                  decoration: BoxDecoration(
                    color: WhizzColors.secondaryContainer,
                    borderRadius: BorderRadius.circular(GoldenRatio.md),
                    border: Border.all(
                      color: WhizzColors.borderPrimary,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.done_all,
                          color: WhizzColors.secondary, size: 20),
                      SizedBox(width: GoldenRatio.md),
                      Text(
                        'Delivered',
                        style: TypographySystem.labelLarge.copyWith(
                          color: WhizzColors.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: GoldenRatio.md),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(GoldenRatio.md),
                  child: Text(
                    'Order successfully delivered to customer',
                    style: TypographySystem.bodySmall.copyWith(
                      color: WhizzColors.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              // CANCELLED/EXPIRED STATES - READ-ONLY INFORMATION
              if (order.status == OrderStatus.cancelled) ...[
                SizedBox(height: GoldenRatio.xl),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(GoldenRatio.lg),
                  decoration: BoxDecoration(
                    color: WhizzColors.errorContainer,
                    borderRadius: BorderRadius.circular(GoldenRatio.md),
                    border: Border.all(
                      color: WhizzColors.borderPrimary,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cancel, color: WhizzColors.error, size: 20),
                      SizedBox(width: GoldenRatio.md),
                      Text(
                        'Order Cancelled',
                        style: TypographySystem.labelLarge.copyWith(
                          color: WhizzColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (order.status == OrderStatus.expired) ...[
                SizedBox(height: GoldenRatio.xl),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(GoldenRatio.lg),
                  decoration: BoxDecoration(
                    color: WhizzColors.warningContainer,
                    borderRadius: BorderRadius.circular(GoldenRatio.md),
                    border: Border.all(
                      color: WhizzColors.borderPrimary,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.timer_off,
                          color: WhizzColors.warning, size: 20),
                      SizedBox(width: GoldenRatio.md),
                      Text(
                        'Order Expired',
                        style: TypographySystem.labelLarge.copyWith(
                          color: WhizzColors.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return WhizzColors.statusPending;
      case OrderStatus.confirmed:
        return WhizzColors.statusConfirmed;
      case OrderStatus.preparing:
        return WhizzColors.statusPreparing;
      case OrderStatus.ready:
        return WhizzColors.statusReady;
      case OrderStatus.readyForPickup: // ✅ الحالة الجديدة
        return WhizzColors.statusReady;
      case OrderStatus.reassigning: // 🔄 جاري البحث عن سائق بديل
        return WhizzColors.warning; // لون برتقالي للتنبيه
      case OrderStatus.completed:
        return WhizzColors.statusDelivered;
      case OrderStatus.cancelled:
        return WhizzColors.statusCancelled;
      case OrderStatus.expired:
        return WhizzColors.statusExpired;
      case OrderStatus.onTheWay:
        return WhizzColors.info;
      // 🚗 حالات السائق - Driver states colors
      case OrderStatus.assigned:
        return WhizzColors.info;
      case OrderStatus.headingToStore:
        return WhizzColors.warning;
      case OrderStatus.arrivedAtStore:
        return WhizzColors.success;
      case OrderStatus.pickedUp:
        return WhizzColors.primary;
      case OrderStatus.headingToCustomer:
        return WhizzColors.primary;
      case OrderStatus.arrivedAtCustomer:
        return WhizzColors.statusDelivered;
      case OrderStatus.delivered:
        return WhizzColors.statusDelivered;
      case OrderStatus.returning:
      case OrderStatus.returnArrived:
      case OrderStatus.returned:
        return WhizzColors.statusReturned;
    }
  }

  String _getStatusText(BuildContext context, OrderStatus status) {
    final loc = AppLocalizations.of(context)!;
    switch (status) {
      case OrderStatus.pending:
        return loc.orderStatusPending;
      case OrderStatus.confirmed:
        return loc.orderStatusConfirmed;
      case OrderStatus.preparing:
        return loc.orderStatusPreparing;
      case OrderStatus.ready:
        return loc.orderStatusReady;
      case OrderStatus.readyForPickup: // ✅ الحالة الجديدة
        return 'جاهز للاستلام'; // أو loc.orderStatusReadyForPickup إذا أضفته في الترجمة
      case OrderStatus.reassigning: // 🔄 جاري البحث عن سائق بديل
        return 'جاري البحث عن سائق...';
      // 🚗 حالات السائق - Driver states text
      case OrderStatus.assigned:
        return 'تم تعيين سائق';
      case OrderStatus.headingToStore:
        return 'السائق في الطريق للمطعم';
      case OrderStatus.arrivedAtStore:
        return 'السائق وصل للمطعم';
      case OrderStatus.pickedUp:
        return 'تم استلام الطلب';
      case OrderStatus.headingToCustomer:
        return 'في الطريق للزبون';
      case OrderStatus.arrivedAtCustomer:
        return 'وصل إلى الزبون';
      case OrderStatus.completed:
        return loc.orderStatusCompleted;
      case OrderStatus.cancelled:
        return loc.orderStatusCancelled;
      case OrderStatus.expired:
        return loc.orderStatusExpired;
      case OrderStatus.onTheWay:
        return loc.orderStatusOnTheWay;
      case OrderStatus.delivered:
        return loc.orderStatusDelivered;
      case OrderStatus.returning:
        return 'جاري إرجاع الطلب';
      case OrderStatus.returnArrived:
        return 'بانتظار تأكيد استلام المرتجع';
      case OrderStatus.returned:
        return loc.orderStatusReturned;
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  /// تحديد متى يجب عرض معلومات السائق
  /// ✅ يظهر من readyForPickup حتى delivered
  /// ❌ لا يظهر عند reassigning (البحث عن سائق بديل)
  bool _shouldShowDriverInfo(OrderStatus status) {
    // إخفاء معلومات السائق عند reassigning
    if (status == OrderStatus.reassigning) {
      return false;
    }

    return status == OrderStatus.readyForPickup ||
        status == OrderStatus.ready ||
        status == OrderStatus.assigned ||
        status == OrderStatus.headingToStore ||
        status == OrderStatus.arrivedAtStore ||
        status == OrderStatus.pickedUp ||
        status == OrderStatus.headingToCustomer ||
        status == OrderStatus.arrivedAtCustomer ||
        status == OrderStatus.delivered ||
        status == OrderStatus.completed;
  }

  /// Helper method لعرض صف معلومات السائق
  Widget _buildDriverInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: GoldenRatio.sm),
      child: Row(
        children: [
          Icon(icon, size: 16, color: WhizzColors.onSurfaceVariant),
          SizedBox(width: GoldenRatio.sm),
          Text(
            '$label: ',
            style: TypographySystem.bodySmall.copyWith(
              color: WhizzColors.onSurfaceVariant,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TypographySystem.bodyMedium.copyWith(
                color: WhizzColors.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
