import 'package:flutter/material.dart';

import '../../domain/entities/task.dart';
import 'organic_theme.dart';

Color quadrantColor(TaskQuadrant quadrant) => switch (quadrant) {
  TaskQuadrant.importantUrgent => KairosColors.clay,
  TaskQuadrant.importantNotUrgent => KairosColors.moss,
  TaskQuadrant.notImportantUrgent => KairosColors.river,
  TaskQuadrant.notImportantNotUrgent => KairosColors.quietInk,
};

String quadrantShortLabel(TaskQuadrant quadrant) => switch (quadrant) {
  TaskQuadrant.importantUrgent => 'Q1 重要且紧急',
  TaskQuadrant.importantNotUrgent => 'Q2 重要不紧急',
  TaskQuadrant.notImportantUrgent => 'Q3 不重要但紧急',
  TaskQuadrant.notImportantNotUrgent => 'Q4 不重要不紧急',
};
