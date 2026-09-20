# Бои Тапков

Idle-игра на Flutter: прокачивай боевой тапок и сражайся 1×1 с тапками других игроков.
Весь арт — код (`CustomPainter`), без растровых ассетов.

## Запуск

```
flutter pub get
flutter run -d chrome     # быстрая отладка в браузере
flutter run               # Android-устройство / эмулятор
flutter test              # тесты боевого движка
```

## Структура

- `lib/game/` — чистый Dart без Flutter: статы тапка, экономика, ELO, детерминированный
  боевой движок (`BattleSim`), генератор соперников (заглушка сервера), состояние игры.
- `lib/ui/` — тема, игровые виджеты (панели, кнопки, бары), отрисовка тапка, экраны.
- `test/tools/render_slipper_test.dart` — рендерит тапки в PNG для визуальной проверки:
  `flutter test test/tools/render_slipper_test.dart --dart-define=OUT=<папка>`.

Шрифт Nunito — SIL Open Font License, см. `assets/fonts/OFL.txt`.
