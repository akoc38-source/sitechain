import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// 🛡️ SiteChain Merkezi Firebase Servis Motoru (v2.301 KML Mühürlü)
class FirebaseServis {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // =======================================================================
  // 🌍 KML / KMZ HARİTA KATMAN YÖNETİMİ METOTLARI
  // =======================================================================

  /// 📂 KML veya KMZ Dosyasını Firebase Storage'a Yükler
  /// ve Firestore 'harita_katmanlari' koleksiyonuna kayıt açar.
  Future<void> kmlDosyaYukleVeEkle(String fileName, File file) async {
    try {
      // 1. Storage referansı oluştur (harita_katmanlari klasörüne benzersiz isimle eklenir)
      final String storagePath =
          'harita_katmanlari/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      final Reference ref = _storage.ref().child(storagePath);

      // 2. Dosyayı Firebase Storage'a yükle
      final UploadTask uploadTask = ref.putFile(file);
      final TaskSnapshot snapshot = await uploadTask;

      // 3. Yüklenen dosyanın indirme bağlantısını (URL) al
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      // 4. Dosya uzantısını belirle (kml / kmz)
      final String extension = fileName.split('.').last.toLowerCase();

      // 5. Firestore 'harita_katmanlari' koleksiyonuna veriyi mühürle
      await _firestore.collection('harita_katmanlari').add({
        'ad': fileName,
        'url': downloadUrl,
        'storage_path': storagePath,
        'tip': extension,
        'yuklenme_tarihi': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("❌ [KML YÜKLEME HATASI]: $e");
      rethrow;
    }
  }

  /// 📡 Veritabanına Yüklü KML / KMZ Katmanlarını Canlı Olarak Dinler
  Stream<QuerySnapshot> kmlKatmanlariniDinle() {
    return _firestore
        .collection('harita_katmanlari')
        .orderBy('yuklenme_tarihi', descending: true)
        .snapshots();
  }

  /// 🗑️ Seçilen KML Katmanını Hem Firestore Dokümanından Hem Depolamadan (Storage) Siler
  Future<void> kmlSil(String docId, String url) async {
    try {
      // 1. Firestore kaydını sil
      await _firestore.collection('harita_katmanlari').doc(docId).delete();

      // 2. Storage üzerindeki fiziksel dosyayı sil
      if (url.isNotEmpty) {
        try {
          final Reference ref = _storage.refFromURL(url);
          await ref.delete();
        } catch (storageError) {
          debugPrint(
            "⚠️ Storage dosyası silinirken uyarı (dosya zaten silinmiş olabilir): $storageError",
          );
        }
      }
    } catch (e) {
      debugPrint("❌ [KML SİLME HATASI]: $e");
      rethrow;
    }
  }
}
