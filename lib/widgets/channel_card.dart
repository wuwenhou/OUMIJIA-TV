import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../theme/design_system.dart';

/// Trạng thái kênh → màu + nhãn gợi ý.
Color statusColor(BuildContext c, String health) {
  final colors = c.c;
  switch (health) {
    case 'WORKING':
      return const Color(0xFF39D98A);
    case 'DEGRADED':
      return const Color(0xFFF5A623);
    case 'OFFLINE':
    case 'INVALID':
      return colors.danger;
    default:
      return colors.textLo; // UNVERIFIED
  }
}

String statusLabel(String health) {
  switch (health) {
    case 'WORKING':
      return 'Đang phát';
    case 'DEGRADED':
      return 'Không ổn định';
    case 'OFFLINE':
      return 'Nguồn lỗi';
    case 'INVALID':
      return 'Cấu hình sai';
    default:
      return 'Chưa kiểm tra';
  }
}

/// Nhãn ngắn cho chip trên diện hẹp (hero, player).
String statusShortLabel(String health) {
  switch (health) {
    case 'WORKING':
      return 'LIVE';
    case 'DEGRADED':
      return 'CHẬM';
    case 'OFFLINE':
      return 'OFFLINE';
    case 'INVALID':
      return 'LỖI';
    default:
      return 'CHƯA RÕ';
  }
}

/// Ô kênh — logo + tên, dùng cho cả grid & list.
/// Logo tải từ config; lỗi ảnh → chữ viết tắt nền accent.
class ChannelCard extends StatelessWidget {
  final Channel channel;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool selected;
  final bool favorite;
  final double height;

  const ChannelCard({
    super.key,
    required this.channel,
    required this.onTap,
    this.onLongPress,
    this.selected = false,
    this.favorite = false,
    this.height = 72,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final healthColor = statusColor(context, channel.health);

    return Material(
      color: selected ? c.surfaceAlt : c.surface,
      borderRadius: BorderRadius.circular(Radii.m),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(Radii.m),
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: Sp.l, vertical: Sp.s + 2),
          decoration: ShapeDecoration(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radii.m),
              side: BorderSide(
                color: selected ? c.accent : c.border,
                width: selected ? 1.4 : 1,
              ),
            ),
          ),
          child: Row(
            children: [
                            ChannelLogo(channel: channel),
              const SizedBox(width: Sp.l),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      channel.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: healthColor),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          statusLabel(channel.health),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: c.textMed),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (favorite) ...[
                Icon(Icons.favorite, color: c.accent, size: 18),
                const SizedBox(width: Sp.s),
              ],
              Icon(Icons.chevron_right, color: c.textLo, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

/// Logo vuông kênh (dùng chung mọi màn): CachedNetworkImage, lỗi → chữ viết tắt.
class ChannelLogo extends StatelessWidget {
  final Channel channel;
  final double size;

  const ChannelLogo({super.key, required this.channel, this.size = 56});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final abbr = channel.name.length > 6 ? 'TV' : channel.name;
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.s),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          border: Border.all(color: c.border),
        ),
        child: channel.logo.isEmpty
            ? Center(child: Text(abbr, style: TextStyle(color: c.accent, fontWeight: FontWeight.w800)))
            : CachedNetworkImage(
                imageUrl: channel.logo,
                fit: BoxFit.contain,
                httpHeaders: const {'User-Agent': 'Mozilla/5.0 (Linux; Android 16) AppleWebKit/537.36'},
                placeholder: (_, __) => const SizedBox.shrink(),
                errorWidget: (_, __, ___) => Center(child: Text(abbr, style: TextStyle(color: c.accent, fontWeight: FontWeight.w800))),
              ),
      ),
    );
  }
}

/// Ô kênh dạng lưới: logo trên, tên dưới, chấm trạng thái + validates.
class ChannelGridTile extends StatelessWidget {
  final Channel channel;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool favorite;

  const ChannelGridTile({
    super.key,
    required this.channel,
    required this.onTap,
    this.onLongPress,
    this.favorite = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final healthColor = statusColor(context, channel.health);
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(Radii.m),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(Radii.m),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.m),
            border: Border.all(color: c.border),
          ),
          padding: const EdgeInsets.all(Sp.m),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(children: [
                ChannelLogo(channel: channel, size: 58),
                if (favorite)
                  Positioned(
                    top: -3,
                    right: -3,
                    child: Icon(Icons.favorite, color: c.accent, size: 16),
                  ),
              ]),
              const SizedBox(height: Sp.s),
              Text(
                channel.name,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: Sp.xs),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: healthColor)),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    statusLabel(channel.health),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ]),
              if (channel.unavailable) ...[
                const SizedBox(height: Sp.xs),
                Text('Không mở được',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: c.danger, fontSize: 11)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Tiêu đề mục + hành động phụ (dùng cho rows trên Home).
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Sp.m),
      child: Row(
        children: [
          Container(width: 3.5, height: 20, decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: Sp.m),
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Chip trạng thái lúc xem player (LIVE / tải / lỗi).
class StatusChip extends StatelessWidget {
  final String text;
  final Color color;
  final bool pulsing;

  const StatusChip({super.key, required this.text, required this.color, this.pulsing = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(Radii.xs + 2),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pulsing) _PulseDot(color: color),
          if (pulsing) const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.35, end: 1.0).animate(_ctrl),
      child: Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color)),
    );
  }
}
