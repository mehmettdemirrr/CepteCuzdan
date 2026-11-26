import 'package:flutter/material.dart';

import '../../models/category.dart';
import '../category_icons.dart';

/// Kategorinin renginde yuvarlak zemin üzerinde ikonu.
class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar(this.category, {super.key, this.size = 40});

  final Category category;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = Color(category.color);
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: color.withValues(alpha: 0.16),
      child: Icon(iconFor(category.icon), color: color, size: size * 0.55),
    );
  }
}
