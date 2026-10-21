import 'package:coad_customer_calls/models/work_task.dart';
import 'package:flutter/material.dart';

const workAssigneePalette = <Color>[
  Color(0xFF1E88E5),
  Color(0xFF00897B),
  Color(0xFF8E24AA),
  Color(0xFF43A047),
  Color(0xFF3949AB),
  Color(0xFFD81B60),
  Color(0xFF00ACC1),
  Color(0xFF6D4C41),
];

Map<String, Color> workAssigneeColors(Iterable<String> emails) {
  final slots = workAssigneeColorSlots(emails);
  return {
    for (final entry in slots.entries)
      entry.key: workAssigneePalette[entry.value % workAssigneePalette.length],
  };
}

Color workAssigneeColor(String email, Map<String, Color> colors) {
  final known = colors[email.trim()];
  if (known != null) return known;
  return const Color(0xFF78909C);
}

Color workAssigneeInk(Color color) {
  return color.computeLuminance() > 0.55
      ? const Color(0xFF1C1C1C)
      : const Color(0xFFFFFFFF);
}

List<Color> workTaskAssigneeColors(WorkTask task, Map<String, Color> colors) {
  final emails = task.assigneeEmails.where(
    (email) => email.trim().isNotEmpty && !workAssigneeHidden(email: email),
  );
  final painted = <Color>[
    for (final email in emails) workAssigneeColor(email, colors),
  ];
  if (painted.isNotEmpty) return painted;
  return const [Color(0xFF78909C)];
}
