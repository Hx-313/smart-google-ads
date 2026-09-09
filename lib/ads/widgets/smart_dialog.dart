import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/material.dart';

import '../ads_service.dart';
import 'banner_ad_controller.dart';

/// Ad-aware wrappers for dialogs and modal surfaces.
///
/// Use these methods instead of Flutter's dialog helpers whenever a banner
/// may be visible. They hide banners for the entire modal lifetime and block
/// app-open ads while the modal is active. Every wrapper restores ad state in
/// a `finally` block, including when the modal is dismissed with an error.
class SmartDialog {
  static final _controller = BannerAdController();
  static int _nextBlockerId = 0;

  static String _openOverlay() {
    _controller.onDialogOpened();
    final reason = 'smart_dialog_${_nextBlockerId++}';
    if (AdsService.isInitialized) {
      AdsService.instance.blockAppOpen(reason);
    }
    return reason;
  }

  static void _closeOverlay(String reason) {
    _controller.onDialogClosed();
    if (AdsService.isInitialized) {
      AdsService.instance.unblockAppOpen(reason);
    }
  }

  /// Show a dialog and automatically hide/show banner ads
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
    Color? barrierColor,
    String? barrierLabel,
    bool useSafeArea = true,
    RouteSettings? routeSettings,
  }) async {
    final blocker = _openOverlay();

    try {
      final result = await showDialog<T>(
        context: context,
        builder: builder,
        barrierDismissible: barrierDismissible,
        barrierColor: barrierColor,
        barrierLabel: barrierLabel,
        useSafeArea: useSafeArea,
        routeSettings: routeSettings,
      );
      return result;
    } finally {
      _closeOverlay(blocker);
    }
  }

  /// Show a Material dialog (AlertDialog, SimpleDialog, etc.)
  static Future<T?> showMaterialDialog<T>({
    required BuildContext context,
    required Widget dialog,
    bool barrierDismissible = true,
  }) {
    return show<T>(
      context: context,
      builder: (context) => dialog,
      barrierDismissible: barrierDismissible,
    );
  }

  /// Show a Cupertino dialog
  static Future<T?> showCupertinoDialog<T>({
    required BuildContext context,
    required Widget dialog,
    bool barrierDismissible = false,
  }) async {
    final blocker = _openOverlay();

    try {
      final result = await showCupertinoDialog<T>(
        context: context,

        barrierDismissible: barrierDismissible,
        dialog: dialog,
      );
      return result;
    } finally {
      _closeOverlay(blocker);
    }
  }

  /// Show a Material bottom sheet
  static Future<T?> showBottomSheet<T>({
    required BuildContext context,
    required Widget Function(BuildContext) builder,
    Color? backgroundColor,
    double? elevation,
    ShapeBorder? shape,
    Clip? clipBehavior,
    BoxConstraints? constraints,
    bool? enableDrag,
    bool isScrollControlled = false,
    bool isDismissible = true,
    bool? useRootNavigator,
  }) async {
    final blocker = _openOverlay();

    try {
      final result = await showModalBottomSheet<T>(
        context: context,
        builder: builder,
        backgroundColor: backgroundColor,
        elevation: elevation,
        shape: shape,
        clipBehavior: clipBehavior,
        constraints: constraints,
        enableDrag: enableDrag ?? true,
        isScrollControlled: isScrollControlled,
        isDismissible: isDismissible,
        useRootNavigator: useRootNavigator ?? false,
      );
      return result;
    } finally {
      _closeOverlay(blocker);
    }
  }

  /// Show a Cupertino action sheet
  static Future<T?> showActionSheet<T>({
    required BuildContext context,
    required Widget actionSheet,
  }) async {
    final blocker = _openOverlay();

    try {
      final result = await showCupertinoModalPopup<T>(
        context: context,
        builder: (context) => actionSheet,
      );
      return result;
    } finally {
      _closeOverlay(blocker);
    }
  }

  /// Show a date picker and hide banner
  static Future<DateTime?> showDatePicker({
    required BuildContext context,
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
    DateTime? currentDate,
    DatePickerEntryMode initialEntryMode = DatePickerEntryMode.calendar,
    String? helpText,
    String? cancelText,
    String? confirmText,
  }) async {
    final blocker = _openOverlay();

    try {
      final result = await material.showDatePicker(
        context: context,
        initialDate: initialDate,
        firstDate: firstDate,
        lastDate: lastDate,
        currentDate: currentDate,
        initialEntryMode: initialEntryMode,
        helpText: helpText,
        cancelText: cancelText,
        confirmText: confirmText,
      );
      return result;
    } finally {
      _closeOverlay(blocker);
    }
  }

  /// Show a time picker and hide banner
  static Future<TimeOfDay?> showTimePicker({
    required BuildContext context,
    required TimeOfDay initialTime,
    String? helpText,
    String? cancelText,
    String? confirmText,
  }) async {
    final blocker = _openOverlay();

    try {
      final result = await material.showTimePicker(
        context: context,
        initialTime: initialTime,
        helpText: helpText,
        cancelText: cancelText,
        confirmText: confirmText,
      );
      return result;
    } finally {
      _closeOverlay(blocker);
    }
  }
}

/// Extension on BuildContext for easy access to SmartDialog
extension SmartDialogExtension on BuildContext {
  /// Show a dialog with automatic banner hiding
  Future<T?> showSmartDialog<T>({
    required WidgetBuilder builder,
    bool barrierDismissible = true,
  }) {
    return SmartDialog.show<T>(
      context: this,
      builder: builder,
      barrierDismissible: barrierDismissible,
    );
  }

  /// Show a material dialog (AlertDialog, SimpleDialog, etc.)
  Future<T?> showSmartAlertDialog<T>(Widget dialog) {
    return SmartDialog.showMaterialDialog<T>(context: this, dialog: dialog);
  }

  /// Show a bottom sheet with automatic banner hiding
  Future<T?> showSmartBottomSheet<T>({
    required Widget Function(BuildContext) builder,
    bool isScrollControlled = false,
  }) {
    return SmartDialog.showBottomSheet<T>(
      context: this,
      builder: builder,
      isScrollControlled: isScrollControlled,
    );
  }
}
