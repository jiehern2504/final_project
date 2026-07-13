part of '../home_page.dart';

class _GreetingSection extends StatelessWidget {
  const _GreetingSection({
    required this.firstName,
    required this.primaryColor,
    required this.secondaryColor,
    required this.textColor,
    required this.onNotificationsTap,
    required this.onAiChatTap,
  });

  final String firstName;
  final Color primaryColor;
  final Color secondaryColor;
  final Color textColor;
  final VoidCallback onNotificationsTap;
  final VoidCallback onAiChatTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hi, $firstName',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: primaryColor,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Let\'s start your workout today!',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _withOpacity(textColor, 0.85),
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StreamBuilder<int>(
              stream: NotificationInboxRepository.instance.watchUnreadCount(),
              initialData: 0,
              builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
                return _TopIconButton(
                  icon: Icons.notifications_none_rounded,
                  iconColor: secondaryColor,
                  tooltip: 'Notifications',
                  onTap: onNotificationsTap,
                  badgeCount: snapshot.data ?? 0,
                );
              },
            ),
            const SizedBox(width: 8),
            _TopIconButton(
              icon: Icons.smart_toy_outlined,
              iconColor: secondaryColor,
              tooltip: 'AI Chat',
              onTap: onAiChatTap,
            ),
          ],
        ),
      ],
    );
  }
}

class _TopIconButton extends StatelessWidget {
  const _TopIconButton({
    required this.icon,
    required this.iconColor,
    this.onTap,
    this.tooltip,
    this.badgeCount = 0,
  });

  final IconData icon;
  final Color iconColor;
  final VoidCallback? onTap;
  final String? tooltip;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final Widget iconWidget = tooltip != null && tooltip!.isNotEmpty
        ? Tooltip(
            message: tooltip!,
            child: Icon(icon, color: iconColor),
          )
        : Icon(icon, color: iconColor);

    final Widget content = badgeCount > 0
        ? Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              iconWidget,
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    badgeCount > 9 ? '9+' : '$badgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ],
          )
        : iconWidget;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _withOpacity(Colors.black, 0.06),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(child: content),
        ),
      ),
    );
  }
}
