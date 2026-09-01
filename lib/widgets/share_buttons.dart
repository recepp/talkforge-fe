import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/app_translations.dart';
import '../services/pdf_export_service.dart';

/// Row of quick-share icon buttons for a generated speech's text.
///
/// WhatsApp, Telegram and X/Twitter all support pre-filling shared text via a
/// plain URL, so those just open the respective share intent in a new tab.
/// Instagram has no such web intent for arbitrary text — there is no URL
/// parameter Instagram accepts to pre-fill a caption/DM — so the closest
/// equivalent is copying the text and opening Instagram for the user to
/// paste it themselves.
class ShareButtons extends StatefulWidget {
  const ShareButtons({
    super.key,
    required this.text,
    this.title,
    this.language,
    this.speechType,
    this.duration,
    this.place,
    this.createdAt,
    this.appLang = 'tr',
  });

  final String text;
  final String? title, language, speechType, duration, place, createdAt;
  final String appLang;

  @override
  State<ShareButtons> createState() => _ShareButtonsState();
}

class _ShareButtonsState extends State<ShareButtons> {
  static const int _whatsappTelegramLimit = 1500;
  static const int _twitterLimit = 250;
  bool _isExportingPdf = false;

  String _truncated(int maxLength) {
    if (widget.text.length <= maxLength) return widget.text;
    return '${widget.text.substring(0, maxLength)}...';
  }

  Future<void> _open(BuildContext context, String url) async {
    try {
      final uri = Uri.parse(url);
      final launched = await launchUrl(uri, webOnlyWindowName: '_blank');
      if (!launched) throw Exception('launchUrl returned false');
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Paylaşım penceresi açılamadı. Tarayıcınızın popup engelleyicisini kontrol edin.'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _shareWhatsApp(BuildContext context) => _open(
      context, 'https://wa.me/?text=${Uri.encodeComponent(_truncated(_whatsappTelegramLimit))}');

  Future<void> _shareTelegram(BuildContext context) => _open(context,
      'https://t.me/share/url?text=${Uri.encodeComponent(_truncated(_whatsappTelegramLimit))}');

  Future<void> _shareTwitter(BuildContext context) => _open(context,
      'https://twitter.com/intent/tweet?text=${Uri.encodeComponent(_truncated(_twitterLimit))}');

  Future<void> _shareInstagram(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Metin kopyalandı. Instagram açıldığında yapıştırabilirsiniz.'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
    }
    if (!context.mounted) return;
    await _open(context, 'https://www.instagram.com/');
  }

  Future<void> _sharePdf(BuildContext context) async {
    if (_isExportingPdf) return;
    setState(() => _isExportingPdf = true);

    if (context.mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppTranslations.tr('pdf_generating', widget.appLang)),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }

    try {
      await PdfExportService.exportTalkPdf(
        title: widget.title ?? 'TalkForge Konuşma Metni',
        text: widget.text,
        language: widget.language,
        speechType: widget.speechType,
        duration: widget.duration,
        place: widget.place,
        createdAt: widget.createdAt,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppTranslations.tr('pdf_export_success', widget.appLang)),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppTranslations.tr('pdf_export_error', widget.appLang)),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ShareIconButton(
          icon: Icons.chat_bubble_rounded,
          color: const Color(0xFF25D366),
          tooltip: 'WhatsApp\'ta paylaş',
          onPressed: () => _shareWhatsApp(context),
        ),
        const SizedBox(width: 8),
        _ShareIconButton(
          icon: Icons.send_rounded,
          color: const Color(0xFF29A9EB),
          tooltip: 'Telegram\'da paylaş',
          onPressed: () => _shareTelegram(context),
        ),
        const SizedBox(width: 8),
        _ShareIconButton(
          icon: Icons.alternate_email_rounded,
          color: const Color(0xFF1DA1F2),
          tooltip: 'X (Twitter)\'da paylaş',
          onPressed: () => _shareTwitter(context),
        ),
        const SizedBox(width: 8),
        _ShareIconButton(
          icon: Icons.camera_alt_rounded,
          color: const Color(0xFFE1306C),
          tooltip: 'Metni kopyala ve Instagram\'ı aç',
          onPressed: () => _shareInstagram(context),
        ),
        const SizedBox(width: 8),
        _ShareIconButton(
          icon: Icons.picture_as_pdf_rounded,
          color: const Color(0xFFEF4444),
          tooltip: AppTranslations.tr('share_pdf', widget.appLang),
          loading: _isExportingPdf,
          onPressed: _isExportingPdf ? null : () => _sharePdf(context),
        ),
      ],
    );
  }
}

class _ShareIconButton extends StatelessWidget {
  const _ShareIconButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
    this.loading = false,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: loading
              ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: color))
              : Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}
