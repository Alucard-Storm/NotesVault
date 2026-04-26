import 'package:flutter/material.dart';
import 'app_exceptions.dart';

/// Utility class for handling and displaying errors consistently across the app
class ErrorHandler {
  /// Converts an exception to a user-friendly error message
  static String getErrorMessage(dynamic error) {
    if (error is AppException) {
      return error.message;
    } else if (error is Exception) {
      return error.toString();
    } else {
      return 'An unexpected error occurred';
    }
  }

  /// Shows an error snackbar
  static void showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Shows an error dialog
  static Future<void> showErrorDialog(
    BuildContext context, {
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
            if (actionLabel != null && onAction != null)
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  onAction();
                },
                child: Text(actionLabel),
              ),
          ],
        );
      },
    );
  }

  /// Validates a string is not empty
  static void validateNotEmpty(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      throw ValidationError('$fieldName cannot be empty');
    }
  }

  /// Validates a title length
  static void validateTitleLength(String title, {int maxLength = 200}) {
    validateNotEmpty(title, 'Title');
    if (title.length > maxLength) {
      throw ValidationError('Title must be less than $maxLength characters');
    }
  }

  /// Validates a vault name length
  static void validateVaultName(String name, {int maxLength = 100}) {
    validateNotEmpty(name, 'Vault name');
    if (name.length > maxLength) {
      throw ValidationError('Vault name must be less than $maxLength characters');
    }
  }
}
