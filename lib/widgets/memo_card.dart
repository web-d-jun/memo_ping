import 'package:flutter/material.dart';
import '../models/memo_item.dart';

class MemoCard extends StatelessWidget {
  final MemoItem item;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const MemoCard({
    super.key,
    required this.item,
    required this.onToggle,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isLocation = item.triggerType == TriggerType.location;
    final triggerColor =
        isLocation ? const Color(0xFF26C6DA) : const Color(0xFFFF8A65);
    final triggerBg =
        isLocation ? const Color(0xFFE0F7FA) : const Color(0xFFFBE9E7);
    final triggerIcon =
        isLocation ? Icons.location_on_rounded : Icons.access_time_rounded;
    final triggerSubIcon =
        isLocation ? Icons.near_me_rounded : Icons.alarm_rounded;

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 28),
      ),
      onDismissed: (_) => onDelete(),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedOpacity(
          opacity: item.isActive ? 1.0 : 0.5,
          duration: const Duration(milliseconds: 250),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // 아이콘
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: triggerBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(triggerIcon, color: triggerColor, size: 26),
                  ),
                  const SizedBox(width: 14),
                  // 내용
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: item.isActive
                                ? const Color(0xFF1A1A2E)
                                : Colors.grey,
                            decoration: item.isActive
                                ? TextDecoration.none
                                : TextDecoration.lineThrough,
                          ),
                        ),
                        if (item.description.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            item.description,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(triggerSubIcon,
                                size: 13, color: triggerColor),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                item.triggerLabel,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: triggerColor,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 토글
                  Switch.adaptive(
                    value: item.isActive,
                    onChanged: (_) => onToggle(),
                    activeColor: const Color(0xFF5C6BC0),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
