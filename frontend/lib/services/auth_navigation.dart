import 'package:flutter/material.dart';

/// Keep the reactive authentication gate; remove every page above it.
/// The navigator is captured before sign-out can dispose the initiating page.
void clearProtectedRoutes(NavigatorState navigator) {
  if (navigator.mounted) navigator.popUntil((route) => route.isFirst);
}
