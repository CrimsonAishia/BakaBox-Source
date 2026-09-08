import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/core.dart';
import 'character_gallery_theme.dart';

class CharacterVoiceCard extends StatefulWidget {
  final List<VoiceItem> voices;
  final bool showType;

  const CharacterVoiceCard({
    super.key,
    required this.voices,
    this.showType = true,
  });

  @override
  State<CharacterVoiceCard> createState() => _CharacterVoiceCardState();
}

class _CharacterVoiceCardState extends State<CharacterVoiceCard> {
  final VoicePlayerService _voiceService = VoicePlayerService();
  bool _hasError = false;

  late List<String> _fullUrls;

  bool _isPlaying = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _updateFullUrls();
    _checkStatus();
    _voiceService.currentPlayingUrl.addListener(_onUrlChanged);
    _voiceService.currentLoadingUrl.addListener(_onUrlChanged);
  }

  @override
  void didUpdateWidget(covariant CharacterVoiceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Use deep check or just simple length & first item url check
    if (oldWidget.voices.length != widget.voices.length ||
        (widget.voices.isNotEmpty &&
            oldWidget.voices.isNotEmpty &&
            oldWidget.voices.first.url != widget.voices.first.url)) {
      _updateFullUrls();
    }
  }

  void _updateFullUrls() {
    _fullUrls = widget.voices.map((v) => EnvConfig.getApiUrl(v.url)).toList();
  }

  void _checkStatus() {
    _isPlaying = _fullUrls.any(
      (url) => _voiceService.currentPlayingUrl.value == url,
    );
    _isLoading = _fullUrls.any(
      (url) => _voiceService.currentLoadingUrl.value == url,
    );
  }

  void _onUrlChanged() {
    if (!mounted) return;
    final wasPlaying = _isPlaying;
    final wasLoading = _isLoading;
    _checkStatus();

    if (wasPlaying != _isPlaying || wasLoading != _isLoading) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _voiceService.currentPlayingUrl.removeListener(_onUrlChanged);
    _voiceService.currentLoadingUrl.removeListener(_onUrlChanged);
    super.dispose();
  }

  Future<void> _togglePlay(int index) async {
    setState(() {
      _hasError = false;
    });
    try {
      await _voiceService.togglePlay(widget.voices[index].url);
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        return; // Ignore downloads cancelled by clicking another voice
      }

      if (mounted) {
        setState(() {
          _hasError = true;
        });
        ToastUtils.showError(
          context,
          '播放语音失败: ${e.toString().split('\n').first}',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if any voice in the group is playing or loading
    final isPlaying = _isPlaying;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    final vermillion = CharacterGalleryTheme.getVermillion(context);
    final activeColor = CharacterGalleryTheme.getSpeedColor(
      context,
    ); // Use Cyan for playing state
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);

    final borderColor = _hasError
        ? Colors.red.withValues(alpha: 0.8)
        : (isPlaying ? activeColor : scrollBrown.withValues(alpha: 0.8));
    final bgColor = _hasError
        ? Colors.red.withValues(alpha: 0.15)
        : (isPlaying
              ? activeColor.withValues(alpha: isDark ? 0.25 : 0.15)
              : scrollBrown.withValues(alpha: isDark ? 0.15 : 0.08));
    const bgAsset = 'assets/images/character_gallery/spell_card_bg_passive.png';

    // Get the representative first voice for the title
    final repVoice = widget.voices.first;

    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Stack(
          children: [
            // Background Layer
            Positioned.fill(
              child: Image.asset(
                bgAsset,
                fit: BoxFit.cover,
                opacity: AlwaysStoppedAnimation(isDark ? 0.3 : 0.6),
              ),
            ),

            // Gradient Mask
            Positioned.fill(
              child: DecoratedBox(
                decoration:
                    CharacterGalleryTheme.getCardBottomGradientDecoration(
                      context,
                    ),
              ),
            ),

            // Content Area
            Material(
              color: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    // Message on the left
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _togglePlay(
                          0,
                        ), // Play the first variant when tapping the text area
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Builder(
                              builder: (context) {
                                String title = repVoice.message;
                                if (title.isEmpty) {
                                  title = repVoice.type;
                                } else if (title.startsWith(' (')) {
                                  title = repVoice.type;
                                } else {
                                  // Optionally remove the suffix like " (1)" to make it clean
                                  if (title.contains(RegExp(r' \(\d+\)$'))) {
                                    title = title.replaceAll(
                                      RegExp(r' \(\d+\)$'),
                                      '',
                                    );
                                  }
                                }
                                return Text(
                                  title,
                                  style: TextStyle(
                                    color: isPlaying ? activeColor : inkColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    shadows: isDark
                                        ? null
                                        : [
                                            Shadow(
                                              color: Colors.white,
                                              blurRadius: 4,
                                            ),
                                            Shadow(
                                              color: Colors.white.withValues(
                                                alpha: 0.9,
                                              ),
                                              blurRadius: 8,
                                            ),
                                          ],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                );
                              },
                            ),
                            if (widget.showType &&
                                repVoice.message.isNotEmpty &&
                                !repVoice.message.startsWith(' (')) ...[
                              Text(
                                repVoice.type,
                                style: TextStyle(
                                  color: inkColor.withValues(alpha: 0.7),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Row of play buttons on the right
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      alignment: WrapAlignment.end,
                      children: List.generate(widget.voices.length, (index) {
                        final url = _fullUrls[index];
                        final isThisPlaying =
                            _voiceService.currentPlayingUrl.value == url;
                        final isThisLoading =
                            _voiceService.currentLoadingUrl.value == url;

                        String tooltipMessage = widget.voices[index].message;
                        if (tooltipMessage.isEmpty ||
                            tooltipMessage.startsWith(' (')) {
                          tooltipMessage =
                              '${widget.voices[index].type} ${index + 1}';
                        }

                        return Tooltip(
                          message: tooltipMessage,
                          child: InkWell(
                            onTap: () => _togglePlay(index),
                            borderRadius: BorderRadius.circular(13),
                            child: SizedBox(
                              width: 26,
                              height: 26,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isThisPlaying
                                          ? activeColor.withValues(alpha: 0.2)
                                          : vermillion.withValues(alpha: 0.05),
                                    ),
                                  ),
                                  if (isThisPlaying)
                                    ValueListenableBuilder<double>(
                                      valueListenable:
                                          _voiceService.currentProgress,
                                      builder: (context, progress, child) {
                                        return CircularProgressIndicator(
                                          value: progress,
                                          strokeWidth: 1.0,
                                          valueColor: AlwaysStoppedAnimation(
                                            vermillion.withValues(alpha: 0.8),
                                          ),
                                          backgroundColor: vermillion
                                              .withValues(alpha: 0.1),
                                        );
                                      },
                                    )
                                  else
                                    CircularProgressIndicator(
                                      value: 1.0,
                                      strokeWidth: 1.0,
                                      valueColor: AlwaysStoppedAnimation(
                                        vermillion.withValues(alpha: 0.3),
                                      ),
                                      backgroundColor: Colors.transparent,
                                    ),
                                  if (isThisLoading)
                                    const Padding(
                                      padding: EdgeInsets.all(6.0),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                      ),
                                    )
                                  else
                                    Icon(
                                      _hasError && isThisPlaying
                                          ? Icons.error_outline_rounded
                                          : (isThisPlaying
                                                ? Icons.pause_rounded
                                                : Icons.play_arrow_rounded),
                                      color: _hasError && isThisPlaying
                                          ? Colors.red
                                          : (isThisPlaying
                                                ? activeColor
                                                : vermillion),
                                      size: 14,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
