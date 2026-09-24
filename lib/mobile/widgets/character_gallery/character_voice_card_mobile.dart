import 'package:flutter/material.dart';
import '../../../core/core.dart';
import '../../../desktop/widgets/character_gallery/character_gallery_theme.dart';

class CharacterVoiceCardMobile extends StatefulWidget {
  final List<VoiceItem> voices;
  final bool showType;

  const CharacterVoiceCardMobile({
    super.key,
    required this.voices,
    this.showType = true,
  });

  @override
  State<CharacterVoiceCardMobile> createState() =>
      _CharacterVoiceCardMobileState();
}

class _CharacterVoiceCardMobileState extends State<CharacterVoiceCardMobile> {
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
  void didUpdateWidget(covariant CharacterVoiceCardMobile oldWidget) {
    super.didUpdateWidget(oldWidget);
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
      if (mounted) {
        setState(() {
          _hasError = true;
        });

        String errMsg;
        if (e is ApiException) {
          errMsg = e.message;
        } else if (e is Exception) {
          errMsg = e.toString().replaceFirst('Exception: ', '');
        } else {
          errMsg = e.toString();
        }

        ToastUtils.showError(context, '播放语音失败: $errMsg');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = _isPlaying;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkColor = CharacterGalleryTheme.getInkColor(context);
    final vermillion = CharacterGalleryTheme.getVermillion(context);
    final activeColor = CharacterGalleryTheme.getSpeedColor(context);
    final scrollBrown = CharacterGalleryTheme.getScrollBrown(context);

    final borderColor = _hasError
        ? Colors.red.withValues(alpha: 0.8)
        : (isPlaying ? activeColor : scrollBrown.withValues(alpha: 0.5));
    final bgColor = _hasError
        ? Colors.red.withValues(alpha: 0.15)
        : (isPlaying
              ? activeColor.withValues(alpha: isDark ? 0.25 : 0.15)
              : scrollBrown.withValues(alpha: isDark ? 0.15 : 0.08));
    const bgAsset = 'assets/images/character_gallery/spell_card_bg_passive.png';

    final repVoice = widget.voices.first;

    final textContent = Column(
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
              if (title.contains(RegExp(r' \(\d+\)$'))) {
                title = title.replaceAll(RegExp(r' \(\d+\)$'), '');
              }
            }
            return Text(
              title,
              style: TextStyle(
                color: isPlaying ? activeColor : inkColor,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            );
          },
        ),
        if (widget.showType &&
            repVoice.message.isNotEmpty &&
            !repVoice.message.startsWith(' (')) ...[
          const SizedBox(height: 2),
          Text(
            repVoice.type,
            style: TextStyle(
              color: inkColor.withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );

    final buttonsWrap = Wrap(
      spacing: 8,
      runSpacing: 6,
      alignment: WrapAlignment.end,
      children: List.generate(widget.voices.length, (index) {
        final url = _fullUrls[index];
        final isThisPlaying = _voiceService.currentPlayingUrl.value == url;
        final isThisLoading = _voiceService.currentLoadingUrl.value == url;

        return GestureDetector(
          onTap: () => _togglePlay(index),
          child: SizedBox(
            width: 30,
            height: 30,
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
                    valueListenable: _voiceService.currentProgress,
                    builder: (context, progress, child) {
                      return CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 1.5,
                        valueColor: AlwaysStoppedAnimation(
                          vermillion.withValues(alpha: 0.8),
                        ),
                        backgroundColor: vermillion.withValues(alpha: 0.1),
                      );
                    },
                  )
                else
                  CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 1.5,
                    valueColor: AlwaysStoppedAnimation(
                      vermillion.withValues(alpha: 0.3),
                    ),
                    backgroundColor: Colors.transparent,
                  ),
                if (isThisLoading)
                  const Padding(
                    padding: EdgeInsets.all(6.0),
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  )
                else
                  Icon(
                    _hasError && isThisPlaying
                        ? Icons.error_outline_rounded
                        : (isThisPlaying
                              ? Icons.stop_rounded
                              : Icons.play_arrow_rounded),
                    color: _hasError && isThisPlaying
                        ? Colors.red
                        : (isThisPlaying ? Colors.red : vermillion),
                    size: 16,
                    shadows: isDark
                        ? [
                            Shadow(
                              color: Colors.white.withValues(alpha: 0.8),
                              blurRadius: 2,
                            ),
                            Shadow(
                              color: Colors.white.withValues(alpha: 0.4),
                              blurRadius: 4,
                            ),
                          ]
                        : null,
                  ),
              ],
            ),
          ),
        );
      }),
    );

    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                bgAsset,
                fit: BoxFit.cover,
                opacity: AlwaysStoppedAnimation(isDark ? 0.3 : 0.6),
              ),
            ),

            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.voices.length == 1 ? () => _togglePlay(0) : null,
                borderRadius: BorderRadius.circular(7),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: widget.voices.length > 4
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            textContent,
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              alignment: Alignment.centerRight,
                              child: buttonsWrap,
                            ),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(child: textContent),
                            const SizedBox(width: 8),
                            buttonsWrap,
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
