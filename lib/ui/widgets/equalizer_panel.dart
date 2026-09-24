import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/player_provider.dart';

/// 10段均衡器面板（基于 SoLoud 原生 Biquad 滤波器）
class EqualizerPanel extends StatefulWidget {
  const EqualizerPanel({super.key});

  @override
  State<EqualizerPanel> createState() => _EqualizerPanelState();
}

class _EqualizerPanelState extends State<EqualizerPanel> {
  static const _bands = [
    _EqBand('64', 64),
    _EqBand('125', 125),
    _EqBand('250', 250),
    _EqBand('500', 500),
    _EqBand('1k', 1000),
    _EqBand('2k', 2000),
    _EqBand('4k', 4000),
    _EqBand('8k', 8000),
  ];

  final List<double> _gains = List.filled(8, 0.5); // 0=min, 0.5=neutral, 1=max
  bool _enabled = false;
  static const double _minDb = -12;
  static const double _maxDb = 12;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '均衡器',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: scheme.onSurface,
              ),
            ),
            const Spacer(),
            Text(
              _enabled ? '已启用' : '已禁用',
              style: TextStyle(fontSize: 12, color: scheme.outline),
            ),
            Switch(
              value: _enabled,
              onChanged: (v) {
                setState(() => _enabled = v);
                final p = context.read<PlayerProvider>();
                if (v) {
                  _applyEq(p);
                } else {
                  _resetEq(p);
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 160,
          child: Row(
            children: List.generate(_bands.length, (i) {
              final gain = (_gains[i] - 0.5) * (_maxDb - _minDb);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        gain >= 0
                            ? '+${gain.toStringAsFixed(0)}'
                            : gain.toStringAsFixed(0),
                        style: TextStyle(fontSize: 9, color: scheme.outline),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: GestureDetector(
                          onTapDown: (d) {
                            _updateGain(i, d.localPosition.dy, 160);
                          },
                          onVerticalDragUpdate: (d) {
                            _updateGain(i, d.localPosition.dy, 160);
                          },
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: scheme.surfaceContainerHighest.withValues(
                                alpha: 0.3,
                              ),
                            ),
                            child: Column(
                              verticalDirection: VerticalDirection.up,
                              children: [
                                Flexible(
                                  flex: ((_gains[i] * 100).round()),
                                  child: Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(4),
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: _enabled
                                            ? [scheme.primary, scheme.tertiary]
                                            : [
                                                scheme.outline.withValues(
                                                  alpha: 0.3,
                                                ),
                                                scheme.outline.withValues(
                                                  alpha: 0.15,
                                                ),
                                              ],
                                      ),
                                    ),
                                  ),
                                ),
                                Flexible(
                                  flex: 100 - (_gains[i] * 100).round(),
                                  child: const SizedBox(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _bands[i].label,
                        style: TextStyle(fontSize: 10, color: scheme.outline),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  void _updateGain(int index, double dy, double height) {
    final normalized = 1.0 - (dy / height).clamp(0.0, 1.0);
    setState(() => _gains[index] = normalized);
    if (_enabled && context.mounted) {
      _applyEq(context.read<PlayerProvider>());
    }
  }

  void _applyEq(PlayerProvider p) {
    p.setEqualizer(true, _gains);
  }

  void _resetEq(PlayerProvider p) {
    setState(() {
      for (var i = 0; i < 8; i++) {
        _gains[i] = 0.5;
      }
    });
    p.setEqualizer(false, _gains);
  }
}

class _EqBand {
  const _EqBand(this.label, this.hz);
  final String label;
  final int hz;
}
