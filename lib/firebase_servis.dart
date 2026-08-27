import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FirebaseServis {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // 📥 KML Katmanlarını Getir
  Future<QuerySnapshot> kmlKatmanlariniGetir() async {
    return await _firestore.collection('kml_katmanlari').get();
  }

  // 🔄 KML Katmanlarını Canlı Dinle
  Stream<QuerySnapshot> kmlKatmanlariniDinle() {
    return _firestore.collection('kml_katmanlari').snapshots();
  }

  // 📤 KML / KMZ Yükleme ve Firestore'a Kaydetme
  Future<void> kmlDosyaYukleVeEkle(String dosyaAdi, File dosya) async {
    String refPath =
        'kml_dosyalari/${DateTime.now().millisecondsSinceEpoch}_$dosyaAdi';
    Reference ref = _storage.ref().child(refPath);

    // Yükleme görevini başlat ve tamamlanmasını bekle
    UploadTask uploadTask = ref.putFile(dosya);
    TaskSnapshot snapshot = await uploadTask;

    // Yükleme bittikten sonra URL al
    String downloadUrl = await snapshot.ref.getDownloadURL();
    String extension = dosyaAdi.split('.').last.toLowerCase();

    // Firestore veritabanına kaydet
    await _firestore.collection('kml_katmanlari').add({
      'ad': dosyaAdi,
      'url': downloadUrl,
      'path': refPath,
      'tip': extension,
      'yuklenmeTarihi': FieldValue.serverTimestamp(),
    });
  }

  // 🗑️ KML Katmanı Silme
  Future<void> kmlSil(String docId, String firestorePath) async {
    try {
      if (firestorePath.isNotEmpty) {
        if (firestorePath.startsWith('http')) {
          await _storage.refFromURL(firestorePath).delete();
        } else {
          await _storage.ref().child(firestorePath).delete();
        }
      }
    } catch (_) {}

    await _firestore.collection('kml_katmanlari').doc(docId).delete();
  }
}
