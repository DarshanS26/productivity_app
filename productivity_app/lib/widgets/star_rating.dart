import 'package:flutter/material.dart';

class StarRating extends StatelessWidget {
  final int rating;
  final ValueChanged<int>? onChanged;
  final Color? activeColor;
  final Color? inactiveColor;
  final double size;

  const StarRating({
    super.key,
    required this.rating,
    this.onChanged,
    this.activeColor,
    this.inactiveColor,
    this.size = 30,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return onChanged != null
            ? InkWell(
                customBorder: const CircleBorder(),
                onTap: () => onChanged!(index + 1),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(
                    index < rating ? Icons.star : Icons.star_border,
                    color: index < rating
                        ? (activeColor ?? Theme.of(context).colorScheme.primary)
                        : (inactiveColor ?? Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                    size: size,
                  ),
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(4.0),
                child: Icon(
                  index < rating ? Icons.star : Icons.star_border,
                  color: index < rating
                      ? (activeColor ?? Theme.of(context).colorScheme.primary)
                      : (inactiveColor ?? Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                  size: size,
                ),
              );
      }),
    );
  }
}

// Display-only star rating widget for showing ratings without interaction
class StarRatingDisplay extends StatelessWidget {
  final int rating;
  final Color? activeColor;
  final Color? inactiveColor;
  final double size;

  const StarRatingDisplay({
    super.key,
    required this.rating,
    this.activeColor,
    this.inactiveColor,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1.0),
          child: Icon(
            index < rating ? Icons.star : Icons.star_border,
            color: index < rating
                ? (activeColor ?? Colors.amber)
                : (inactiveColor ?? Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
            size: size,
          ),
        );
      }),
    );
  }
}
