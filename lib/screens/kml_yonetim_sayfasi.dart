// lib/screens/kml_yonetim_sayfasi.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';

class KmlYonetimSayfasi extends StatefulWidget {
  const KmlYonetimSayfasi({super.key});

  @override
  State<KmlYonetimSayfasi> createState() => _KmlYonetimSayfasiState();
}

class _KmlYonetimSayfasiState extends State<KmlYonetimSayfasi> {
  bool _yukleniyor = false;

  // 📂 DOSYA SEÇ VE YÜKLE (KML/KMZ DESTEKLİ)
  Future<void> _dosyaEkle() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['kml', 'kmz'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() => _yukleniyor = true);

      try {
        File file = File(result.files.single.path!);
        String fileName = result.files.single.name;
        String fileExtension = fileName.split('.').last.toLowerCase();

        // 1. Firebase Storage'a yükle
        String storagePath =
            'kml_dosyalari/${DateTime.now().millisecondsSinceEpoch}_$fileName';
        Reference ref = FirebaseStorage.instance.ref().child(storagePath);
        UploadTask uploadTask = ref.putFile(file);
        TaskSnapshot snapshot = await uploadTask;
        String downloadUrl = await snapshot.ref.getDownloadURL();

        // 2. Firestore 'kml_katmanlari' koleksiyonuna kaydet
        await FirebaseFirestore.instance.collection('kml_katmanlari').add({
          'ad': fileName,
          'tip': fileExtension,
          'url': downloadUrl,
          'storage_path': storagePath,
          'yukleme_tarihi': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✅ Katman başarıyla yüklendi!"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("⚠️ Yükleme Hatası: $e"),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _yukleniyor = false);
        }
      }
    }
  }

  // 🗑️ KATMAN VE DOSYA SİLME
  Future<void> _katmanSil(String docId, String url) async {
    try {
      // 1. Firestore kaydını sil
      await FirebaseFirestore.instance
          .collection('kml_katmanlari')
          .doc(docId)
          .delete();

      // 2. Storage üzerindeki dosyayı sil
      if (url.isNotEmpty) {
        try {
          await FirebaseStorage.instance.refFromURL(url).delete();
        } catch (e) {
          debugPrint("Storage dosya silme uyarısı: $e");
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("🗑️ Katman ve dosya başarıyla silindi."),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("⚠️ Silme Hatası: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121824),
      appBar: AppBar(
        title: const Text("KML / KMZ YÖNETİMİ"),
        backgroundColor: const Color(0xFF1E2638),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance.collection('kml_katmanlari').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF9F1C)),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "Henüz yüklü bir katman yok.",
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.only(top: 10, bottom: 80),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              var data = docs[i].data() as Map<String, dynamic>;
              String docId = docs[i].id;
              String url = data['url'] ?? "";

              return Card(
                color: const Color(0xFF1E2638),
                margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.white12),
                ),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFF9F1C),
                    child: Icon(Icons.layers, color: Colors.black, size: 20),
                  ),
                  title: Text(
                    data['ad'] ?? "İsimsiz Katman",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    "Tip: ${data['tip']?.toString().toUpperCase() ?? 'KML'}",
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.delete_forever,
                      color: Colors.redAccent,
                    ),
                    onPressed: () => _katmanSil(docId, url),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFFF9F1C),
        foregroundColor: Colors.black,
        onPressed: _yukleniyor ? null : _dosyaEkle,
        label: _yukleniyor
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.black,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                "YENİ KATMAN EKLE",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
        icon: const Icon(Icons.cloud_upload),
      ),
    );
  }
}
