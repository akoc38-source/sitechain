// lib/models/project_model.dart

enum ProjectType {
  sulamaBoru, // 🌊 Sulama & Boru Hattı
  elektrikKablo, // ⚡ Elektrik & Kablo Hattı
  icmeSuyuKanal, // 💧 İçme Suyu & Kanalizasyon
  yolOtoyol, // 🛣️ Yol & Otoyol
  demiryolu, // 🚆 Demiryolu & Metro
  telekomFiber, // 📡 Fiber Optik & Telekom
  ozel, // 🛠️ Özel Proje
}

class ProjectTypeConfig {
  static Map<ProjectType, Map<String, dynamic>> configs = {
    ProjectType.sulamaBoru: {
      'title': 'Sulama & Boru Hattı',
      'icon': '🌊',
      'stages': [
        '1. Kazı Aşaması',
        '2. Çakıl Yataklama',
        '3. Boru Montajı',
        '4. Geri Dolgu / Kapama'
      ],
      'defaultUnits': 'm',
    },
    ProjectType.elektrikKablo: {
      'title': 'Elektrik & Enerji Hatları',
      'icon': '⚡',
      'stages': [
        '1. Kanal Kazısı',
        '2. Kablo Yataklama',
        '3. Kablo Çekimi',
        '4. Kanal Kapama'
      ],
      'defaultUnits': 'm',
    },
    ProjectType.icmeSuyuKanal: {
      'title': 'İçme Suyu & Kanalizasyon',
      'icon': '💧',
      'stages': [
        '1. Hafriyat Kazısı',
        '2. Yataklama',
        '3. Boru/Büz Döşeme',
        '4. Dolgu & Asfaltlama'
      ],
      'defaultUnits': 'm',
    },
    ProjectType.yolOtoyol: {
      'title': 'Yol & Otoyol Projesi',
      'icon': '🛣️',
      'stages': [
        '1. Yarma / Kazı',
        '2. Subbas / Dolgu',
        '3. Binder / Asfalt',
        '4. Bordür & Kaldırım'
      ],
      'defaultUnits': 'm',
    },
    ProjectType.demiryolu: {
      'title': 'Demiryolu & Metro',
      'icon': '🚆',
      'stages': [
        '1. Altyapı Hazırlığı',
        '2. Balast Serme',
        '3. Ray / Travers Döşeme',
        '4. Elektrifikasyon'
      ],
      'defaultUnits': 'm',
    },
    ProjectType.telekomFiber: {
      'title': 'Fiber Optik & Telekom',
      'icon': '📡',
      'stages': [
        '1. Micro-Trench Kazı',
        '2. Boru Çekimi',
        '3. Fiber Üfleme',
        '4. Kapatma & Asfalt'
      ],
      'defaultUnits': 'm',
    },
    ProjectType.ozel: {
      'title': 'Özel / Serbest Proje',
      'icon': '🛠️',
      'stages': ['1. Aşama 1', '2. Aşama 2', '3. Aşama 3', '4. Aşama 4'],
      'defaultUnits': 'm',
    },
  };
}
