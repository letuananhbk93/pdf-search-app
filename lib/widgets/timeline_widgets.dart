import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

const Color kTimelineBordeaux = Color(0xFFC00000);

/// Lets mouse, trackpad and stylus drag-scroll the tables. Flutter web only drag-scrolls touch by default,
/// so on a PC the table could only be moved with the wheel or the scrollbar.
class TimelineScrollBehavior extends MaterialScrollBehavior {
  const TimelineScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      };
}

AppBar buildTimelineAppBar({List<Widget> actions = const [], bool automaticallyImplyLeading = true}) {
  return AppBar(
    title: const Text('TIMELINE', style: TextStyle(color: Colors.white)),
    backgroundColor: kTimelineBordeaux,
    iconTheme: const IconThemeData(color: Colors.white),
    automaticallyImplyLeading: automaticallyImplyLeading,
    actions: actions,
  );
}

/// Bar colour by completion: red below 50%, amber from 50% to 99%, green at 100%.
Color timelineProgressColor(double pct) {
  final rounded = pct.round();
  if (rounded >= 100) return Colors.green.shade600;
  if (rounded >= 50) return Colors.amber.shade700;
  return Colors.red.shade600;
}

/// "dd/mm/yyyy hh:mm" in local time, from the UTC ISO string the server sends.
String formatTimelineDateTime(String? iso) {
  if (iso == null) return 'Unknown';
  final local = DateTime.parse(iso).toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
}

class TimelineBreadcrumb extends StatelessWidget {
  const TimelineBreadcrumb({super.key, required this.path});

  /// Labels from TIMELINE down to the current screen, e.g. ['TIMELINE', '2026', 'PO7', 'Supplier A'].
  final List<String> path;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        path.join(' > '),
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black54),
      ),
    );
  }
}

class TimelineProgressCard extends StatelessWidget {
  const TimelineProgressCard({
    super.key,
    required this.title,
    required this.pct,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final double pct;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = timelineProgressColor(pct);
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${pct.round()}%',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (pct / 100).clamp(0.0, 1.0),
                  minHeight: 10,
                  color: color,
                  backgroundColor: Colors.grey.shade200,
                ),
              ),
              const SizedBox(height: 8),
              Text(subtitle, style: const TextStyle(color: Colors.black54)),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Last updated: ..." line shown under the breadcrumb on every TIMELINE screen.
class TimelineLastUpdated extends StatelessWidget {
  const TimelineLastUpdated({super.key, required this.lastUpdated});

  final String? lastUpdated;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(
        'Last updated: ${formatTimelineDateTime(lastUpdated)}',
        style: const TextStyle(fontSize: 12, color: Colors.black45),
      ),
    );
  }
}
