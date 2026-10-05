import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../game/game_state.dart';
import '../net/server_api.dart';
import 'theme.dart';
import 'widgets/game_widgets.dart';

/// Блок «Новости» на главной: последняя новость и красная точка, если
/// есть непрочитанные.
class NewsTile extends StatelessWidget {
  const NewsTile({super.key, required this.game});
  final GameState game;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final latest = game.news.first;
    return GamePanel(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => NewsScreen(game: game))),
      child: Row(
        children: [
          const Icon(Icons.campaign_rounded, color: GameColors.gold, size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Новости', style: theme.textTheme.titleMedium),
                    if (game.hasUnreadNews) ...[
                      const SizedBox(width: 8),
                      const _Dot(),
                    ],
                  ],
                ),
                Text(
                  latest.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: GameColors.textDim),
        ],
      ),
    );
  }
}

/// Список новостей: свежие сверху, непрочитанные с точкой.
class NewsScreen extends StatelessWidget {
  const NewsScreen({super.key, required this.game});
  final GameState game;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: ListenableBuilder(
            listenable: game,
            builder: (context, _) => Column(
              children: [
                _Header(title: 'Новости'),
                Expanded(
                  child: game.news.isEmpty
                      ? Center(
                          child: Text(
                            'Пока новостей нет',
                            style: theme.textTheme.titleMedium,
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: game.news.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final n = game.news[i];
                            final unread = !game.readNews.contains(n.id);
                            return GamePanel(
                              padding: const EdgeInsets.all(12),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      NewsArticleScreen(game: game, item: n),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      if (unread) ...[
                                        const _Dot(),
                                        const SizedBox(width: 8),
                                      ],
                                      Expanded(
                                        child: Text(
                                          n.title,
                                          style: theme.textTheme.titleSmall,
                                        ),
                                      ),
                                      Text(
                                        _date(n.date),
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              color: GameColors.textDim,
                                            ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    n.body,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Новость целиком. Открытие отмечает её прочитанной.
class NewsArticleScreen extends StatefulWidget {
  const NewsArticleScreen({super.key, required this.game, required this.item});
  final GameState game;
  final NewsItem item;

  @override
  State<NewsArticleScreen> createState() => _NewsArticleScreenState();
}

class _NewsArticleScreenState extends State<NewsArticleScreen> {
  @override
  void initState() {
    super.initState();
    widget.game.markNewsRead(widget.item);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final n = widget.item;
    // Упомянутые телеграм-ники (@name) — кнопками «Написать».
    final handles = {
      for (final m in RegExp(r'@([A-Za-z0-9_]{4,})').allMatches(n.body))
        m.group(1)!,
    };
    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Column(
            children: [
              _Header(title: 'Новости'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    GamePanel(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(n.title, style: theme.textTheme.titleLarge),
                          const SizedBox(height: 4),
                          Text(
                            _date(n.date),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: GameColors.textDim,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SelectableText(
                            n.body,
                            style: theme.textTheme.bodyMedium,
                          ),
                          for (final h in handles) ...[
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: GameButton(
                                color: GameColors.blue,
                                height: 46,
                                onPressed: () => launchUrl(
                                  Uri.parse('https://t.me/$h'),
                                  mode: LaunchMode.externalApplication,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.send_rounded, size: 18),
                                    const SizedBox(width: 8),
                                    Text('Написать @$h'),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _date(DateTime d) {
  final l = d.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(l.day)}.${two(l.month)}.${l.year}';
}

class _Header extends StatelessWidget {
  const _Header({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
    child: Row(
      children: [
        GameButton(
          onPressed: () => Navigator.of(context).pop(),
          color: GameColors.panelLight,
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: const Icon(Icons.arrow_back_rounded, color: GameColors.text),
        ),
        Expanded(child: Center(child: StrokeText(title, size: 28))),
        const SizedBox(width: 44),
      ],
    ),
  );
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) => Container(
    width: 12,
    height: 12,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: GameColors.red,
      border: Border.all(color: GameColors.outline, width: 2),
    ),
  );
}
