import 'dart:ui';

import 'package:slipper_core/battle/combatant.dart';
import 'package:slipper_core/gems.dart';
import 'package:slipper_core/slipper_kind.dart';

// В ядре цвета хранятся числами (оно не зависит от Flutter) — здесь они
// превращаются в Color для интерфейса.

extension RarityColor on Rarity {
  Color get color => Color(argb);
}

extension GemTypeColor on GemType {
  Color get color => Color(argb);
}

extension AuraSpecColor on AuraSpec {
  Color get color => Color(argb);
}
