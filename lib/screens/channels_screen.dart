import 'package:flutter/material.dart';

import '../models.dart';
import '../services/config_service.dart';
import '../services/prefs_service.dart';
import '../theme/design_system.dart';
import '../widgets/channel_card.dart';
import 'favorites_screen.dart';
import 'player_screen.dart';

/// Tab KÊNH — tìm kiếm + lọc theo nhóm + list/grid + kéo-làm-mới cấu hình
/// từ GitHub (cập nhật danh mục không cần phát hành APK mới).
class ChannelsScreen extends StatefulWidget {
  final AppConfig config;
  final void Function(AppConfig config)? onConfigChanged;

  const ChannelsScreen({super.key, required this.config, this.onConfigChanged});

  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> {
  String _query = '';
  String _group = 'Tất cả';
  bool _grid = false;
  bool _reloadBusy = false;

  @override
  void initState() {
    super.initState();
    _grid = PrefsService.gridView;
  }

  List<Channel> get _filtered {
    final query = _query.trim();
    final all = query.isEmpty
        ? widget.config.channels
        : widget.config.searchChannels(query);
    if (_group == 'Tất cả') return all;
    return all.where((c) => c.group == _group).toList();
  }

  List<String> get _groups {
    final set = <String>{'Tất cả'};
    for (final c in widget.config.channels) {
      set.add(c.group);
    }
    return set.toList();
  }

  Future<void> _reload() async {
    if (_reloadBusy) return;
    setState(() => _reloadBusy = true);
    try {
      final cfg = await ConfigService.load();
      widget.onConfigChanged?.call(cfg);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_sourceLabel(cfg.source)),
          duration: const Duration(seconds: 2),
        ));
      }
    } finally {
      if (mounted) setState(() => _reloadBusy = false);
    }
  }

  String _sourceLabel(String source) {
    switch (source) {
      case 'remote':
        return 'Đã cập nhật danh mục từ GitHub';
      case 'cache':
        return 'Dùng bản lưu gần nhất (không có mạng)';
      default:
        return 'Dùng bản kênh đóng gói trong app';
    }
  }

  void _open(Channel ch) {
    if (ch.unavailable) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${ch.name}: ${statusLabel(ch.health)}. '
            'Kênh này chưa có nguồn phát hợp lệ.'),
      ));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => PlayerScreen(config: widget.config, channel: ch),
    ));
  }

  Future<void> _toggleFavorite(Channel ch) async {
    await PrefsService.toggleFavorite(ch.id);
    if (mounted) setState(() {});
  }

  void _setGrid(bool v) {
    setState(() => _grid = v);
    PrefsService.setGridView(v);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final items = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kênh truyền hình'),
        actions: [
          IconButton(
            tooltip: 'Kênh yêu thích',
            icon: const Icon(Icons.favorite_border_rounded),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => FavoritesScreen(config: widget.config),
              ));
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: Sp.s),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, icon: Icon(Icons.view_list, size: 18)),
                ButtonSegment(value: true, icon: Icon(Icons.grid_view_rounded, size: 18)),
              ],
              selected: {_grid},
              showSelectedIcon: false,
              onSelectionChanged: (sel) => _setGrid(sel.first),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ---- tìm kiếm ----
          Padding(
            padding: const EdgeInsets.fromLTRB(Sp.xl, Sp.s, Sp.xl, Sp.s),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Tìm kênh — ví dụ "VTV3"',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: (_query.isEmpty && _group == 'Tất cả')
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Xóa bộ lọc',
                        onPressed: () => setState(() {
                          _query = '';
                          _group = 'Tất cả';
                        }),
                      ),
              ),
            ),
          ),
          // ---- nhóm kênh ----
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Sp.xl),
              children: [
                for (final g in _groups)
                  Padding(
                    padding: const EdgeInsets.only(right: Sp.s),
                    child: ChoiceChip(
                      label: Text(g),
                      selected: _group == g,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _group = g),
                    ),
                  ),
              ],
            ),
          ),
          // ---- số kênh ----
          Padding(
            padding: const EdgeInsets.fromLTRB(Sp.xl, Sp.s, Sp.xl, Sp.s),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              runSpacing: 2,
              children: [
                Text('${items.length} kênh',
                    style: Theme.of(context).textTheme.bodySmall),
                Text('Kéo xuống để làm mới',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: c.textLo)),
              ],
            ),
          ),
          // ---- danh sách / lưới ----
          Expanded(
            child: RefreshIndicator(
              onRefresh: _reload,
              child: items.isEmpty
                  ? _EmptyFilterState(
                      onReset: () => setState(() {
                        _query = '';
                        _group = 'Tất cả';
                      }),
                    )
                  : _grid
                      ? GridView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(Sp.xl, 0, Sp.xl, Sp.xxl + Sp.l),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 190,
                            mainAxisSpacing: Sp.s + 2,
                            crossAxisSpacing: Sp.s + 2,
                            childAspectRatio: 0.95,
                          ),
                          itemCount: items.length,
                          itemBuilder: (context, i) {
                            final ch = items[i];
                            return ChannelGridTile(
                              channel: ch,
                              favorite: PrefsService.isFavorite(ch.id),
                              onTap: () => _open(ch),
                              onLongPress: () => _toggleFavorite(ch),
                            );
                          },
                        )
                      : ListView.separated(
                          padding:
                              const EdgeInsets.fromLTRB(Sp.xl, 0, Sp.xl, Sp.xxl + Sp.l),
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: Sp.s + 2),
                          itemBuilder: (context, i) {
                            final ch = items[i];
                            return ChannelCard(
                              channel: ch,
                              favorite: PrefsService.isFavorite(ch.id),
                              onTap: () => _open(ch),
                              onLongPress: () => _toggleFavorite(ch),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Không tìm thấy kết quả nào → nút Xóa bộ lọc trả về toàn bộ kênh.
class _EmptyFilterState extends StatelessWidget {
  final VoidCallback onReset;

  const _EmptyFilterState({required this.onReset});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 46, color: c.textLo),
          const SizedBox(height: Sp.m),
          Text('Không có kênh nào khớp bộ lọc',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: Sp.xs),
          Text('Thử từ khóa khác hoặc mở lại cả nhóm.',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: Sp.l),
          OutlinedButton(onPressed: onReset, child: const Text('Xóa bộ lọc')),
        ],
      ),
    );
  }
}
