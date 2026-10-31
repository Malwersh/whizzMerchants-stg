import 'package:flutter/material.dart';
import 'product_form_screen.dart';

class AddProductScreen extends StatelessWidget {
  final String? businessId;
  const AddProductScreen({super.key, this.businessId});
  @override
  Widget build(BuildContext context) =>
      ProductFormScreen(businessId: businessId);
}
