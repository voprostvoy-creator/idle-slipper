"""Нормализует PNG тапка под формат игры.

Что делает:
  - убирает полупрозрачный шум по краям (alpha < NOISE -> 0);
  - обрезает по контуру непрозрачных пикселей;
  - вписывает в холст 2:1 с полями и одинаковой «линией пола»;
  - печатает подсказку по якорям (верхний контур, пятка, подошва).

Запуск:
  python tool/normalize_slipper.py <входной.png> <id> [папка] [--webp]
Результат: <папка>/<id>.png (1200x600), по умолчанию assets/slippers.
С --webp сохраняет WebP: в 6-7 раз легче PNG без видимой разницы.
Противники сюжета: python tool/normalize_slipper.py fly.png fly assets/enemies --webp
"""
import sys

sys.stdout.reconfigure(encoding="utf-8")
from pathlib import Path

import numpy as np
from PIL import Image

W, H = 1200, 600      # холст 2:1
MARGIN_X = 0.04       # поле слева/справа, доля ширины
FLOOR = 0.92          # где стоит подошва, доля высоты
NOISE = 24            # alpha ниже этого считаем мусором


def main(src: str, slipper_id: str, folder: str, webp: bool) -> None:
    im = Image.open(src).convert("RGBA")
    arr = np.array(im)
    alpha = arr[:, :, 3]
    alpha[alpha < NOISE] = 0
    arr[:, :, 3] = alpha
    im = Image.fromarray(arr)

    bbox = im.getbbox()
    if bbox is None:
        sys.exit("пустая картинка")
    im = im.crop(bbox)

    # Масштаб: по ширине с полями, но чтобы по высоте тоже влезло.
    max_w = W * (1 - 2 * MARGIN_X)
    max_h = H * (FLOOR - 0.04)
    scale = min(max_w / im.width, max_h / im.height)
    im = im.resize((round(im.width * scale), round(im.height * scale)), Image.LANCZOS)

    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    x = (W - im.width) // 2
    y = round(H * FLOOR) - im.height
    canvas.paste(im, (x, y), im)

    out = Path(folder) / f"{slipper_id}.{'webp' if webp else 'png'}"
    out.parent.mkdir(parents=True, exist_ok=True)
    if webp:
        canvas.save(out, "WEBP", quality=90, method=6)
    else:
        canvas.save(out)
    print(f"сохранено {out}: тапок {im.width}x{im.height} на холсте {W}x{H}")

    _print_anchor_hints(np.array(canvas)[:, :, 3])


def _print_anchor_hints(alpha: np.ndarray) -> None:
    """Подсказка по якорям: верхний контур в нескольких колонках, пятка, подошва."""
    h, w = alpha.shape
    cols = np.where(alpha.max(axis=0) > 128)[0]
    rows = np.where(alpha.max(axis=1) > 128)[0]
    left, right = cols.min(), cols.max()
    top, bottom = rows.min(), rows.max()
    print("\nПодсказка по якорям (доли 0..1; ridge — по верхнему контуру):")
    print("  ridge: [")
    for f in (0.35, 0.5, 0.65, 0.8, 0.9):
        cx = int(left + (right - left) * f)
        ys = np.where(alpha[:, cx] > 128)[0]
        if len(ys):
            print(f"    Offset({cx / w:.2f}, {ys.min() / h:.2f}),")
    print("  ],")
    mid_y = (top + bottom) / 2
    print(f"  heel: Offset({left / w:.2f}, {mid_y / h:.2f}),")
    print(f"  sole: Rect.fromLTRB({(left + (right - left) * 0.12) / w:.2f}, "
          f"{(bottom - (bottom - top) * 0.12) / h:.2f}, "
          f"{(left + (right - left) * 0.88) / w:.2f}, {(bottom - 4) / h:.2f}),")
    print("  side: точки на боку подбери глазами, например по центру верха.")


if __name__ == "__main__":
    flags = [a for a in sys.argv[1:] if a.startswith("--")]
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if len(args) not in (2, 3) or set(flags) - {"--webp"}:
        sys.exit(__doc__)
    main(args[0], args[1], args[2] if len(args) == 3 else "assets/slippers",
         "--webp" in flags)
