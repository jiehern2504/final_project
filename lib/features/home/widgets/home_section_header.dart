part of '../home_page.dart';

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.textColor,
    this.actionLabel,
    this.accentColor,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final Color textColor;
  final Color? accentColor;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        if (actionLabel != null)
          TextButton.icon(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: accentColor ?? textColor,
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            iconAlignment: IconAlignment.end,
            icon: Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: accentColor,
            ),
            label: Text(actionLabel!),
          ),
      ],
    );
  }
}
