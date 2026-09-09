import '../ads_types.dart';

abstract class BaseAdHandler {
  AdState state = AdState.idle;

  Future<bool> load();
  Future<bool> show();
  void dispose();

  bool get isLoaded => state == AdState.loaded;
  bool get isShowing => state == AdState.showing;
  bool get isIdle => state == AdState.idle;
}
