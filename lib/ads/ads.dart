import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:yandex_mobileads/mobile_ads.dart';

import '../audio/music.dart';
import '../ui/theme.dart';
import '../ui/toast.dart';

/// Реклама за награду через Рекламную сеть Яндекса (РСЯ).
///
/// Ролик держится загруженным заранее, чтобы по нажатию показывался сразу.
/// Награда — только если ролик досмотрен (так требует РСЯ).
class Ads {
  Ads._();
  static final instance = Ads._();

  /// Блок «Rewarded» в кабинете РСЯ. В отладке — демо-блок Яндекса,
  /// чтобы не накручивать показы своему.
  static const _unitId = kDebugMode ? 'demo-rewarded-yandex' : 'R-M-20161676-1';

  /// Реклама есть только в приложении на телефоне; в браузере награда
  /// выдаётся сразу — для проверки.
  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  final _loader = RewardedAdLoader();
  RewardedAd? _ad;
  Future<RewardedAd?>? _loading;
  bool _showing = false;

  Future<void> init() async {
    if (!supported) return;
    try {
      await YandexAds.initialize();
      _preload();
    } catch (e) {
      debugPrint('Ads: $e');
    }
  }

  /// Загрузить следующий ролик, если ещё не загружен.
  Future<RewardedAd?> _preload() {
    if (_ad != null) return Future.value(_ad);
    return _loading ??= () async {
      try {
        _ad = await _loader.loadAd(
          adRequest: const AdRequest(adUnitId: _unitId),
        );
      } on AdRequestError catch (e) {
        debugPrint('Ads: не загрузилась: ${e.code} ${e.description}');
        _ad = null;
      } catch (e) {
        debugPrint('Ads: $e');
        _ad = null;
      } finally {
        _loading = null;
      }
      return _ad;
    }();
  }

  /// Показать ролик. true — досмотрен, награду выдавать.
  Future<bool> showRewarded(BuildContext context) async {
    if (!supported) return true;
    if (_showing) return false;
    _showing = true;
    try {
      // Ещё не загрузился — подождём немного с крутилкой.
      final ad = _ad ?? await _waitWithSpinner(context);
      if (ad == null) {
        if (context.mounted) {
          showToast(
            context,
            'Реклама пока не загрузилась, попробуй чуть позже',
          );
        }
        _preload();
        return false;
      }
      _ad = null;
      var failed = false;
      ad.setAdEventListener(
        eventListener: RewardedAdEventListener(
          onAdFailedToShow: (e) {
            failed = true;
            debugPrint('Ads: не показалась: ${e.description}');
          },
        ),
      );
      // Своя музыка не должна играть поверх ролика.
      Music.instance.hold();
      try {
        await ad.show();
        final reward = await ad.waitForDismiss();
        return !failed && reward != null;
      } finally {
        Music.instance.release();
        ad.destroy();
        _preload();
      }
    } catch (e) {
      debugPrint('Ads: $e');
      return false;
    } finally {
      _showing = false;
    }
  }

  Future<RewardedAd?> _waitWithSpinner(BuildContext context) async {
    final future = _preload().timeout(
      const Duration(seconds: 10),
      onTimeout: () => null,
    );
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: GameColors.gold),
      ),
    );
    final ad = await future;
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    return ad;
  }
}
