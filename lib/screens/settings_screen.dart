import 'dart:io';
import 'package:flutter/material.dart';
import '../compress_service.dart';
import '../widgets/glowing_container.dart';


class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _cacheSize = 0;
  bool _isLoadingCache = true;
  bool _isClearingCache = false;

  @override
  void initState() {
    super.initState();
    _loadCacheSize();
  }

  Future<void> _loadCacheSize() async {
    setState(() => _isLoadingCache = true);
    try {
      final size = await CompressService.getCacheSize();
      if (mounted) setState(() { _cacheSize = size; _isLoadingCache = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoadingCache = false);
    }
  }

  Future<void> _clearCache() async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1435),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('ยืนยันการลบ Cache', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'จะลบไฟล์ cache ทั้งหมด ${CompressService.formatBytes(_cacheSize)} ออกจากแอป',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 16),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'ไฟล์ที่ยังไม่ได้บันทึกลงคลังภาพจะถูกลบถาวร',
                      style: TextStyle(color: Colors.amber, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('ลบ Cache', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isClearingCache = true);
    try {
      await CompressService.clearAllCache();
      await _loadCacheSize();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white),
              SizedBox(width: 8),
              Text('ลบ Cache เรียบร้อยแล้ว'),
            ],
          ),
          backgroundColor: Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isClearingCache = false);
    }
  }

  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 4.0),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 13)),
          Text(
            value,
            style: TextStyle(color: valueColor ?? Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [

          // ── CACHE SECTION ───────────────────────────────────────────────
          _buildSectionTitle('จัดการ Cache', Icons.storage_rounded, const Color(0xFF00E5FF)),
          GlowingContainer(
            gradientColors: const [Color(0xFF130E26), Color(0xFF1A1435)],
            shadowColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cache size display
                  Row(
                    children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF00E5FF), Color(0xFF0097A7)]),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.folder_outlined, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('ไฟล์ชั่วคราว & Cache', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 4),
                            _isLoadingCache
                              ? const SizedBox(
                                  height: 12, width: 12,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00E5FF)),
                                )
                              : Text(
                                  CompressService.formatBytes(_cacheSize),
                                  style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.w700, fontSize: 18),
                                ),
                          ],
                        ),
                      ),
                      // Refresh button
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, color: Colors.white38, size: 20),
                        onPressed: _loadCacheSize,
                        tooltip: 'รีเฟรช',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white12, height: 1),
                  const SizedBox(height: 12),
                  const Text(
                    'แอปนี้ import ไฟล์รูปภาพและวิดีโอเข้ามาประมวลผลในเครื่อง ทำให้ใช้พื้นที่เพิ่มขึ้นตามเวลา การลบ Cache จะช่วยเพิ่มพื้นที่ว่าง',
                    style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isClearingCache ? null : _clearCache,
                      icon: _isClearingCache
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.delete_sweep_rounded),
                      label: Text(_isClearingCache ? 'กำลังลบ Cache...' : 'ลบ Cache ทั้งหมด'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.redAccent.withOpacity(0.9),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 4,
                        shadowColor: Colors.redAccent.withOpacity(0.3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── APP INFO SECTION ─────────────────────────────────────────────
          _buildSectionTitle('ข้อมูลแอปพลิเคชัน', Icons.info_outline_rounded, const Color(0xFF8E2DE2)),
          GlowingContainer(
            gradientColors: const [Color(0xFF130E26), Color(0xFF1A1435)],
            shadowColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                children: [
                  _buildInfoRow('ชื่อแอป', 'Smart Compressor'),
                  const Divider(color: Colors.white12, height: 16),
                  _buildInfoRow('เวอร์ชัน', '1.0.0'),
                  const Divider(color: Colors.white12, height: 16),
                  _buildInfoRow('โหมดการทำงาน', 'Offline 100%', valueColor: Colors.greenAccent),
                  const Divider(color: Colors.white12, height: 16),
                  _buildInfoRow('ระบบปฏิบัติการ', Platform.isIOS ? 'iOS' : Platform.isAndroid ? 'Android' : 'Other'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── FEATURES SECTION ──────────────────────────────────────────────
          _buildSectionTitle('ฟีเจอร์', Icons.auto_awesome_rounded, const Color(0xFFD500F9)),
          GlowingContainer(
            gradientColors: const [Color(0xFF130E26), Color(0xFF1A1435)],
            shadowColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                children: [
                  _buildFeatureRow(Icons.image_outlined, 'บีบอัดรูปภาพ', 'JPEG, PNG, WEBP, HEIC — หลายภาพพร้อมกัน', const Color(0xFFE040FB)),
                  const Divider(color: Colors.white12, height: 20),
                  _buildFeatureRow(Icons.auto_awesome_motion_rounded, 'เพิ่มความคมชัดรูปภาพ', 'Upscale ถึง 4K, HDR, Denoise — หลายภาพพร้อมกัน', const Color(0xFF00E5FF)),
                  const Divider(color: Colors.white12, height: 20),
                  _buildFeatureRow(Icons.video_library_outlined, 'บีบอัดวิดีโอ', 'H.264/H.265 Hardware Encode — หลายวิดีโอพร้อมกัน', const Color(0xFF8E2DE2)),
                  const Divider(color: Colors.white12, height: 20),
                  _buildFeatureRow(Icons.auto_awesome, 'เพิ่มความคมชัดวิดีโอ', 'HDR Boost, Denoise — หลายวิดีโอพร้อมกัน', const Color(0xFFD500F9)),
                  const Divider(color: Colors.white12, height: 20),
                  _buildFeatureRow(Icons.transform_rounded, 'แปลงฟอร์แมตรูปภาพ', 'แปลงระหว่าง JPEG, PNG, WEBP, HEIC', const Color(0xFF4CAF50)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── PRIVACY SECTION ───────────────────────────────────────────────
          _buildSectionTitle('ความเป็นส่วนตัว', Icons.security_rounded, Colors.greenAccent),
          GlowingContainer(
            gradientColors: const [Color(0xFF0A1A0A), Color(0xFF0F1E0F)],
            shadowColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.lock_outline_rounded, color: Colors.greenAccent, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'แอปนี้ทำงานออฟไลน์ 100% ไม่มีการอัปโหลดข้อมูลหรือไฟล์ใด ๆ ไปยังเซิร์ฟเวอร์ภายนอก ข้อมูลทั้งหมดอยู่บนอุปกรณ์ของคุณ',
                      style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String subtitle, Color color) {
    return Row(
      children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ],
          ),
        ),
        Icon(Icons.check_circle_rounded, color: color, size: 16),
      ],
    );
  }
}
