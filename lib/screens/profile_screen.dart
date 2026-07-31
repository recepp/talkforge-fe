import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: Text(
          'Profilim',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 20,
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(32.0),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(24.0),
              border: Border.all(color: const Color(0xFF334155), width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // User Avatar Placeholder
                const CircleAvatar(
                  radius: 50,
                  backgroundColor: Color(0xFF312E81),
                  child: Icon(
                    Icons.account_circle,
                    size: 80,
                    color: Color(0xFF818CF8),
                  ),
                ),
                const SizedBox(height: 20),
                // Nickname
                Text(
                  authProvider.nickname ?? 'Kullanıcı',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                // Role Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: authProvider.role == 'admin'
                        ? Colors.amber.withOpacity(0.1)
                        : const Color(0xFF334155),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: authProvider.role == 'admin'
                          ? Colors.amber.withOpacity(0.3)
                          : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    authProvider.role == 'admin' ? 'Yönetici / Admin' : 'Standart Kullanıcı',
                    style: GoogleFonts.inter(
                      color: authProvider.role == 'admin' ? Colors.amber : const Color(0xFF94A3B8),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                const Divider(color: Color(0xFF334155)),
                const SizedBox(height: 16),
                // User Details Rows
                Row(
                  children: [
                    const Icon(Icons.email_outlined, color: Color(0xFF64748B)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'E-posta Adresi',
                            style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 11),
                          ),
                          Text(
                            authProvider.email ?? '',
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                // Logout Button
                ElevatedButton.icon(
                  onPressed: () => authProvider.logout(),
                  icon: const Icon(Icons.logout),
                  label: const Text('Çıkış Yap'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.withOpacity(0.1),
                    foregroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Colors.redAccent, width: 1),
                    ),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
