import 'package:flutter/foundation.dart';

/// True while the Premium upgrade overlay is visible on screen.
/// MainNavigation listens to this to hide the logo behind the modal.
final ValueNotifier<bool> premiumUpgradeVisible = ValueNotifier(false);
