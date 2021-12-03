import 'package:flutter/material.dart';

// 先頭 n 文字を取得（n 文字以上なら先頭 (n-1) 文字＋「…」）
String formatLabel(String label, int len) {
  final int shortLen = len - 1;
  return (label.length < (len + 1)
      ? label
      : '${label.substring(0, shortLen)}…');
}

// 暗幕表示
void showCircularProgressIndicator(BuildContext context) {
  showGeneralDialog(
      context: context,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 250),
      barrierColor: Colors.black.withOpacity(0.5),
      pageBuilder: (BuildContext context, Animation animation,
          Animation secondaryAnimation) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      });
}
