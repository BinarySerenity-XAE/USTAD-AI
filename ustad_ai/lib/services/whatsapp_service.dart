import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/student_model.dart';
import '../theme/app_theme.dart';

class WhatsAppService {
  /// Send a WhatsApp message.
  /// If [phone] is provided and non-empty, opens direct chat with that number.
  /// If [phone] is null or empty, opens WhatsApp's universal contact/group picker
  /// allowing user to pick any class group or contact.
  static Future<bool> sendMessage({
    String? phone,
    required String message,
  }) async {
    // Safety Backup: Auto-copy text to clipboard so user can always paste it
    try {
      await Clipboard.setData(ClipboardData(text: message));
    } catch (e) {
      debugPrint('Clipboard backup error: $e');
    }

    final encodedMessage = Uri.encodeComponent(message);

    // 1. Direct phone number flow if a phone number was supplied
    if (phone != null && phone.trim().isNotEmpty) {
      final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
      if (digits.isNotEmpty && digits != '923001234567') {
        String cleanPhone = digits;
        if (cleanPhone.startsWith('03')) {
          cleanPhone = '92${cleanPhone.substring(1)}';
        } else if (cleanPhone.startsWith('0')) {
          cleanPhone = '92${cleanPhone.substring(1)}';
        } else if (!cleanPhone.startsWith('92') && cleanPhone.length == 10) {
          cleanPhone = '92$cleanPhone';
        }

        // Try native WhatsApp direct scheme: whatsapp://send?phone=...
        try {
          final nativeUri = Uri.parse('whatsapp://send?phone=$cleanPhone&text=$encodedMessage');
          final launched = await launchUrl(
            nativeUri,
            mode: LaunchMode.externalNonBrowserApplication,
          );
          if (launched) return true;
        } catch (e) {
          debugPrint('Direct whatsapp:// launch failed: $e');
        }

        // Try wa.me standard link
        try {
          final waMeUri = Uri.parse('https://wa.me/$cleanPhone?text=$encodedMessage');
          final launched = await launchUrl(
            waMeUri,
            mode: LaunchMode.externalApplication,
          );
          if (launched) return true;
        } catch (e) {
          debugPrint('wa.me launch failed: $e');
        }

        // Fallback to api.whatsapp.com with phone
        try {
          final apiUri = Uri.parse('https://api.whatsapp.com/send?phone=$cleanPhone&text=$encodedMessage');
          final launched = await launchUrl(
            apiUri,
            mode: LaunchMode.externalApplication,
          );
          if (launched) return true;
        } catch (e) {
          debugPrint('api.whatsapp.com launch failed: $e');
        }
      }
    }

    // 2. Universal Contact & Group Picker Flow:
    // If no phone was provided, WhatsApp launches directly and opens its
    // contact and group selector screen so the teacher/admin can pick any
    // class group (e.g. "Class 5 Parents Group") or any contact!
    try {
      final nativePickerUri = Uri.parse('whatsapp://send?text=$encodedMessage');
      final launched = await launchUrl(
        nativePickerUri,
        mode: LaunchMode.externalNonBrowserApplication,
      );
      if (launched) return true;
    } catch (e) {
      debugPrint('whatsapp:// picker launch failed: $e');
    }

    // Web fallback for group/contact picker
    try {
      final webPickerUri = Uri.parse('https://api.whatsapp.com/send?text=$encodedMessage');
      final launched = await launchUrl(
        webPickerUri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return true;
    } catch (e) {
      debugPrint('api.whatsapp.com picker launch failed: $e');
    }

    return false;
  }

  /// Displays an interactive WhatsApp Share Dialog.
  /// Never opens a dummy or unknown number without user selection.
  /// Allows the user to:
  ///   1. Share directly to any WhatsApp Group or Contact with 1 tap.
  ///   2. Enter/edit a custom WhatsApp number.
  ///   3. Pick a student from the class roster (if students list is provided).
  static Future<bool> showShareDialog({
    required BuildContext context,
    required String message,
    String? title,
    String? subtitle,
    String? initialPhone,
    List<StudentModel>? students,
  }) async {
    final phoneController = TextEditingController(text: initialPhone ?? '');

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF25D366).withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.chat_bubble_rounded,
                                color: Color(0xFF25D366),
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title ?? 'Share via WhatsApp',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.navyBlue,
                                    ),
                                  ),
                                  if (subtitle != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      subtitle,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.grey),
                              onPressed: () => Navigator.pop(ctx, false),
                              tooltip: 'Close',
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Option 1: 1-Tap Group / Contact Share
                        Material(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () async {
                              Navigator.pop(ctx, true);
                              final sent = await sendMessage(message: message);
                              if (context.mounted && sent) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('📲 WhatsApp opened! Select any group or contact to share.'),
                                    backgroundColor: Color(0xFF25D366),
                                  ),
                                );
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF25D366),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.groups_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Share to Class Group / Any Chat',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: Color(0xFF1B5E20),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Opens WhatsApp to pick your class group or any contact',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right, color: Color(0xFF1B5E20)),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(child: Divider(color: Colors.grey.shade300)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                'OR ENTER SPECIFIC NUMBER',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            Expanded(child: Divider(color: Colors.grey.shade300)),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Option 2: Enter specific phone number
                        TextField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'WhatsApp Phone Number',
                            hintText: 'e.g. 03001234567 or 92300...',
                            prefixIcon: const Icon(Icons.phone_android, color: Color(0xFF25D366)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            isDense: true,
                            suffixIcon: phoneController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      phoneController.clear();
                                      setDialogState(() {});
                                    },
                                  )
                                : null,
                          ),
                          onChanged: (_) => setDialogState(() {}),
                        ),
                        const SizedBox(height: 10),

                        ElevatedButton.icon(
                          onPressed: () async {
                            final phone = phoneController.text.trim();
                            Navigator.pop(ctx, true);
                            final sent = await sendMessage(
                              phone: phone.isNotEmpty ? phone : null,
                              message: message,
                            );
                            if (context.mounted && sent) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    phone.isNotEmpty
                                        ? '📲 WhatsApp opened for $phone'
                                        : '📲 WhatsApp opened to choose contact/group',
                                  ),
                                  backgroundColor: const Color(0xFF25D366),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                          label: Text(
                            phoneController.text.trim().isNotEmpty
                                ? 'Send Direct to Number'
                                : 'Open WhatsApp Contact Picker',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),

                        // Option 3: Student list (if supplied)
                        if (students != null && students.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(child: Divider(color: Colors.grey.shade300)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Text(
                                  'OR SELECT STUDENT PARENT (${students.length})',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              Expanded(child: Divider(color: Colors.grey.shade300)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Material(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              constraints: const BoxConstraints(maxHeight: 180),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade200),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListView.separated(
                                shrinkWrap: true,
                                itemCount: students.length,
                                separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
                                itemBuilder: (listCtx, idx) {
                                  final s = students[idx];
                                  final phone = (s.whatsappNumber != null && s.whatsappNumber!.isNotEmpty)
                                      ? s.whatsappNumber!
                                      : (s.phone ?? '');
                                  return ListTile(
                                    dense: true,
                                    visualDensity: VisualDensity.compact,
                                    leading: CircleAvatar(
                                      radius: 14,
                                      backgroundColor: AppTheme.navyBlue.withOpacity(0.1),
                                      child: Text(
                                        s.rollNumber ?? '${idx + 1}',
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.navyBlue),
                                      ),
                                    ),
                                    title: Text(
                                      s.name,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                    subtitle: Text(
                                      phone.isNotEmpty ? 'Parent: $phone' : 'No phone saved',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: phone.isNotEmpty ? Colors.black87 : Colors.red.shade400,
                                      ),
                                    ),
                                    trailing: const Icon(Icons.send_rounded, color: Color(0xFF25D366), size: 18),
                                    onTap: () async {
                                      Navigator.pop(ctx, true);
                                      final sent = await sendMessage(
                                        phone: phone.isNotEmpty ? phone : null,
                                        message: message,
                                      );
                                      if (context.mounted && sent) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('📲 WhatsApp opened for ${s.name}\'s parent!'),
                                            backgroundColor: const Color(0xFF25D366),
                                          ),
                                        );
                                      }
                                    },
                                  );
                                },
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    return result ?? false;
  }
}
