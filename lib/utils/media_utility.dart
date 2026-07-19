import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'package:gal/gal.dart';

class MediaUtility {
  static Future<void> shareFile(File file, String name) async {
    final xFile = XFile(file.path);
    await Share.shareXFiles([xFile], text: 'บีบอัดด้วยแอป Compress Offline!');
  }

  static Future<void> openFile(File file) async {
    await OpenFilex.open(file.path);
  }

  static Future<void> saveToGallery(BuildContext context, File file, {required bool isVideo}) async {
    try {
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final request = await Gal.requestAccess();
        if (!request) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('โปรดอนุญาตการเข้าถึงคลังรูปภาพในการตั้งค่าเครื่องเพื่อบันทึก'),
              backgroundColor: Colors.redAccent,
            ),
          );
          return;
        }
      }

      if (isVideo) {
        await Gal.putVideo(file.path);
      } else {
        await Gal.putImage(file.path);
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('บันทึกลงในคลังรูปภาพ (Photos) เรียบร้อยแล้ว!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ไม่สามารถบันทึกได้: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }
}
