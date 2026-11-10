import 'package:flutter/material.dart';

import '../theme/app_design.dart';
import 'surface_texture.dart';

/// 页面标题区：图标 + 眉标 + 标题 + 副标题 + 右侧操作。
class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
    this.eyebrow,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final String? eyebrow;
  final IconData icon;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final textStyles = context.textStyles;

    final heading = Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.primary.withValues(alpha: 0.2),
                scheme.primaryContainer.withValues(alpha: 0.75),
              ],
            ),
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: scheme.primary.withValues(alpha: 0.22)),
          ),
          child: Icon(icon, size: 20, color: scheme.primary),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (eyebrow != null)
                Text(
                  eyebrow!.toUpperCase(),
                  style: textStyles.labelSmall?.copyWith(
                    color: scheme.primary,
                    letterSpacing: 1.1,
                  ),
                ),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textStyles.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textStyles.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < AppBreakpoints.compactHeader;
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.page,
            AppSpacing.page,
            AppSpacing.md,
          ),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    heading,
                    if (actions.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: actions,
                      ),
                    ],
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: heading),
                    if (actions.isNotEmpty) ...[
                      const SizedBox(width: AppSpacing.page),
                      Flexible(
                        child: Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          alignment: WrapAlignment.end,
                          children: actions,
                        ),
                      ),
                    ],
                  ],
                ),
        );
      },
    );
  }
}

/// 统一的卡片/面板容器，支持纹理与浮起层级。
class AppPanel extends StatelessWidget {
  const AppPanel({
    super.key,
    required this.child,
    this.padding = AppSpacing.cardInsets,
    this.color,
    this.elevated = false,
    this.clip = true,
    this.texture,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final bool elevated;
  final bool clip;
  final SurfaceTextureKind? texture;

  @override
  Widget build(BuildContext context) {
    final visual = context.visual;
    final isDark = context.isDark;
    final padded = Padding(padding: padding, child: child);
    final content = texture == null
        ? padded
        : TexturedSurface(kind: texture!, child: padded);
    const radius = AppRadius.mdAll;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? (elevated ? visual.elevatedPanel : visual.panel),
        borderRadius: radius,
        border: Border.all(color: visual.border),
        boxShadow: elevated
            ? AppShadows.elevated(visual.shadow)
            : AppShadows.soft(
                visual.shadow.withValues(alpha: isDark ? 0.14 : 0.045),
              ),
      ),
      child: clip ? ClipRRect(borderRadius: radius, child: content) : content,
    );
  }
}

class AppSectionTitle extends StatelessWidget {
  const AppSectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: context.textStyles.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyles.labelSmall?.copyWith(
                    color: context.scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// 统一的媒体列表行：选中态、悬浮态与拖拽态视觉一致。
class AppMediaRow extends StatelessWidget {
  const AppMediaRow({
    super.key,
    required this.title,
    required this.leading,
    required this.trailing,
    this.subtitle,
    this.onTap,
    this.selected = false,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
  });

  final String title;
  final String? subtitle;
  final Widget leading;
  final Widget trailing;
  final VoidCallback? onTap;
  final bool selected;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final visual = context.visual;

    return AnimatedContainer(
      duration: AppMotion.normal,
      curve: AppMotion.curve,
      decoration: BoxDecoration(
        color: selected ? visual.selected : Colors.transparent,
        borderRadius: AppRadius.smAll,
        border: Border.all(
          color: selected
              ? scheme.primary.withValues(alpha: 0.24)
              : Colors.transparent,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.smAll,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.smAll,
          hoverColor: visual.hover,
          highlightColor: scheme.primary.withValues(alpha: 0.08),
          child: Padding(
            padding: padding,
            child: Row(
              children: [
                if (selected)
                  Container(
                    width: 3,
                    height: 28,
                    margin: const EdgeInsets.only(right: AppSpacing.sm),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [scheme.primary, scheme.tertiary],
                      ),
                      borderRadius: AppRadius.xsAll,
                    ),
                  ),
                leading,
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textStyles.titleSmall?.copyWith(
                          height: 1.25,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: selected ? scheme.primary : scheme.onSurface,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: AppSpacing.xxs + 1),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textStyles.bodySmall?.copyWith(
                            height: 1.25,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(child: trailing),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 统一的封面容器：占位渐变、圆角、加载与错误回退。
class AppCover extends StatelessWidget {
  const AppCover({
    super.key,
    this.imageProvider,
    this.size = 44,
    this.icon = Icons.music_note_rounded,
  });

  final ImageProvider? imageProvider;
  final double size;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final placeholder = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primaryContainer, scheme.secondaryContainer],
        ),
      ),
      child: Icon(icon, size: size * 0.4, color: scheme.onPrimaryContainer),
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: AppRadius.smAll,
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: ClipRRect(
        borderRadius: AppRadius.xsAll,
        child: imageProvider == null
            ? placeholder
            : Image(
                image: imageProvider!,
                fit: BoxFit.cover,
                frameBuilder: (context, child, frame, _) =>
                    frame == null ? placeholder : child,
                errorBuilder: (context, error, stackTrace) => placeholder,
              ),
      ),
    );
  }
}

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final visual = context.visual;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.primary.withValues(alpha: 0.18),
                    visual.panelMuted,
                  ],
                ),
                borderRadius: AppRadius.lgAll,
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.18),
                ),
                boxShadow: AppShadows.glow(
                  scheme.primary,
                  alpha: context.isDark ? 0.14 : 0.08,
                ),
              ),
              child: Icon(icon, size: 28, color: scheme.primary),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: context.textStyles.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (description != null) ...[
              const SizedBox(height: AppSpacing.sm),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Text(
                  description!,
                  textAlign: TextAlign.center,
                  style: context.textStyles.bodySmall?.copyWith(
                    height: 1.6,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
