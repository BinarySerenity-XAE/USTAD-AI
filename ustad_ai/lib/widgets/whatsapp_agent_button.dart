import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/whatsapp_service.dart';

/// Discreet Floating WhatsApp Action Button for Parent Mode.
/// Positioned in the lower-left corner to connect parents directly
/// to the automated School WhatsApp Agent (03077486000).
class WhatsAppAgentButton extends StatelessWidget {
  final String phone;
  final String? initialMessage;
  final double size;

  const WhatsAppAgentButton({
    super.key,
    this.phone = '03077486000',
    this.initialMessage = 'Assalam-o-Alaikum! I have a question regarding Sublime Grammar School.',
    this.size = 48.0,
  });

  // Official WhatsApp SVG Logo (White)
  static const String _whatsappSvg = '''
<svg viewBox="0 0 24 24" fill="white" xmlns="http://www.w3.org/2000/svg">
  <path d="M12.04 2C6.58 2 2.13 6.45 2.13 11.91C2.13 13.66 2.59 15.36 3.45 16.86L2.05 22L7.3 20.62C8.75 21.41 10.38 21.83 12.04 21.83C17.5 21.83 21.95 17.38 21.95 11.92C21.95 9.27 20.92 6.78 19.05 4.91C17.18 3.03 14.69 2 12.04 2ZM12.04 20.16C10.56 20.16 9.11 19.76 7.85 19.01L7.55 18.83L4.43 19.65L5.26 16.61L5.06 16.29C4.24 14.99 3.8 13.47 3.8 11.91C3.8 7.37 7.5 3.67 12.04 3.67C14.25 3.67 16.31 4.53 17.87 6.09C19.42 7.65 20.28 9.72 20.28 11.92C20.28 16.46 16.58 20.16 12.04 20.16ZM16.56 14.39C16.31 14.27 15.09 13.67 14.86 13.58C14.63 13.5 14.47 13.46 14.3 13.71C14.14 13.96 13.67 14.51 13.53 14.67C13.39 14.84 13.24 14.86 12.99 14.73C12.75 14.61 11.96 14.35 11.02 13.51C10.29 12.86 9.8 12.05 9.66 11.8C9.51 11.55 9.64 11.42 9.77 11.29C9.88 11.18 10.02 11 10.14 10.86C10.27 10.72 10.31 10.61 10.39 10.45C10.47 10.28 10.43 10.14 10.37 10.02C10.31 9.9 9.82 8.69 9.61 8.2C9.41 7.72 9.21 7.78 9.06 7.77C8.92 7.77 8.75 7.76 8.59 7.76C8.42 7.76 8.16 7.82 7.93 8.07C7.7 8.32 7.06 8.92 7.06 10.14C7.06 11.36 7.95 12.53 8.07 12.7C8.19 12.86 9.82 15.37 12.31 16.44C12.9 16.7 13.36 16.85 13.72 16.96C14.31 17.15 14.85 17.12 15.28 17.06C15.75 16.99 16.73 16.47 16.93 15.89C17.14 15.32 17.14 14.84 17.08 14.73C17.02 14.63 16.81 14.52 16.56 14.39Z"/>
</svg>
''';

  void _launchWhatsApp(BuildContext context) {
    try {
      WhatsAppService.sendMessage(
        phone: phone,
        message: initialMessage ?? 'Assalam-o-Alaikum!',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open WhatsApp: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Chat with School WhatsApp Assistant ($phone)',
      child: Material(
        color: Colors.transparent,
        elevation: 4,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: () => _launchWhatsApp(context),
          borderRadius: BorderRadius.circular(size / 2),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: const Color(0xFF25D366),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF25D366).withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: SvgPicture.string(
                _whatsappSvg,
                width: size * 0.54,
                height: size * 0.54,
                placeholderBuilder: (_) => Icon(
                  Icons.chat_bubble_rounded,
                  color: Colors.white,
                  size: size * 0.52,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
