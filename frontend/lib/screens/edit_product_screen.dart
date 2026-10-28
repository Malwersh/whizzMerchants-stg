import 'package:flutter/material.dart';
import '../models/product.dart';
import 'product_form_screen.dart';

class EditProductScreen extends StatelessWidget {
  final Product product;
  const EditProductScreen({super.key, required this.product});
  @override
  Widget build(BuildContext context) =>
      ProductFormScreen(product: product, businessId: product.businessId);
}
