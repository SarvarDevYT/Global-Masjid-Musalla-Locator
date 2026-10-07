# Global Masjid & Musalla Locator

> **Dunyo bo‘ylab musulmonlar va sayohatchilar uchun mo‘ljallangan, ultra-tezkor mobil ilova, Vercel Serverless PostGIS API, Neon Cloud ma'lumotlar bazasi, S3 Object Storage, Admin Boshqaruv Paneli va Zamonaviy Landing Sahifasi.**

---

## 🌟 Loyiha Arxitekturasi

Platforma 3 ta asosiy bo'g'indan iborat:
1. **Flutter Mobil Ilovasi (`/mobile`):** iOS va Android uchun cross-platform ilova. Geofazoviy qidiruv, 100% offline-first kesh, real-vaqt Qibla kompasi, tahoratxona filtrlari va ko'p tillilik (UZ, EN, RU, AR, TR).
2. **Neon Cloud & PostGIS Backend (`/backend`):** Node.js + Express arxitekturasi. Neon serverless PostgreSQL va PostGIS spatial indekslari (`ST_DWithin`, `ST_DistanceSphere`), Neon S3 Object Storage (rasmlar uchun) hamda OpenStreetMap Overpass integratsiyasi.
3. **Vercel Serverless & Veb Portallar (`/backend/public`):**
   - **Landing Sahifasi (`/`):** Mahsulot taqdimoti, jonli brauzer masjid qidiruvchisi (demo), QR kod va to'g'ridan-to'g'ri Android APK yuklab olish tugmasi.
   - **Admin Boshqaruv Paneli (`/admin`):** Yangi masjidlarni tasdiqlash/moderatsiya, rasmlar yuklash, foydalanuvchilar shikoyatlarini ko'rish va OpenStreetMap dan hududlar bo'yicha masjidlarni bazaga import qilish.

---

## 📁 Kataloglar Strukturasi

```
Global Masjid & Musalla Locator/
├── vercel.json                    # Vercel Serverless deployment konfiguratsiyasi (Root)
├── release/                       # Ishlab chiqarilgan tayyor Android APK fayllari
│   └── Global_Masjid_Locator.apk
│
├── backend/                       # Node.js + Neon PostGIS Serverless Backend
│   ├── api/
│   │   └── index.js               # Vercel Serverless function kirish nuqtasi
│   ├── public/                    # Veb interfeyslar (Vercel CDN / Static)
│   │   ├── index.html             # Zamonaviy Landing Page (Jonli qidiruv & APK yuklash)
│   │   ├── app.css & app.js       # Landing sahifasi stillari va jonli demo logikasi
│   │   ├── admin/                 # Admin Boshqaruv Paneli
│   │   │   ├── index.html         # Dashboard (Masjidlar, Moderatsiya, OSM Sync)
│   │   │   ├── admin.css          # Dark glassmorphism admin stillari
│   │   │   └── admin.js           # Admin paneli API ulanishlari va CSRF himoyasi
│   │   └── downloads/             # Foydalanuvchilar yuklab olishi uchun APK papkasi
│   ├── src/
│   │   ├── config/                # Muhit o'zgaruvchilari (Neon, S3, JWT, Admin hash)
│   │   ├── db/                    # PostGIS schema.sql, seeds.js, spatial database.js
│   │   ├── middleware/            # AdminAuth (JWT/bcrypt/CSRF), Validation (Zod), Security
│   │   ├── routes/                # Mosques (/nearby, /contribute, /report), Admin, Upload
│   │   ├── services/              # OpenStreetMap Overpass & Neon S3 Storage servislari
│   │   ├── app.js                 # Express ilova sozlamalari (Helmet CSP, CORS, Rate Limit)
│   │   └── server.js              # Lokal va serverless startup
│   ├── tests/                     # Unit & Spatial avtotestlar
│   ├── vercel.json                # Backend alohida deploy qilingandagi Vercel sozlamasi
│   └── package.json
│
└── mobile/                        # Flutter Mobil Ilovasi (Android & iOS)
    ├── lib/
    │   ├── core/                  # AppColors, ApiConstants, L10n (5 ta til), Qibla formulalari
    │   ├── data/                  # MosqueModel, SharedPreferences Kesh, ApiService, Location
    │   ├── providers/             # Riverpod State Notifiers
    │   ├── ui/                    # HomeScreen (Split View), QiblaScreen, AddMosqueScreen, Settings
    │   └── main.dart              # Mobil ilova kirish nuqtasi
    └── pubspec.yaml
```

---

## 🚀 Vercel-ga 1-Qadamda Deploy Qilish (Backendni Kompyuteringizda Yoqmasdan Ishlatish)

Loyiha to'liq **Vercel Serverless** uchun optimallashtirilgan. Backend o'z kompyuteringizda ishlamasdan, Vercel bulutida tunu-kun 100% bepul ishlaydi!

### Deploy jarayoni:
1. [Vercel Dashboard](https://vercel.com) ga kiring va **"Add New Project"** tugmasini bosing.
2. `https://github.com/SarvarDevYT/Global-Masjid-Musalla-Locator` repozitoriyasini tanlang (**Import**).
3. **Environment Variables** bo'limiga quyidagi kalitlarni kiriting:

```env
DATABASE_URL=postgresql://neondb_owner:npg_j0mlIGTCi6Pc@ep-weathered-grass-b2rmpww4.c-6.eu-central-1.aws.neon.tech/neondb?sslmode=require&channel_binding=require
DATABASE_URL_POOLED=postgresql://neondb_owner:npg_j0mlIGTCi6Pc@ep-weathered-grass-b2rmpww4-pooler.c-6.eu-central-1.aws.neon.tech/neondb?sslmode=require&channel_binding=require

AWS_ENDPOINT_URL_S3=https://br-sparkling-bread-b25swc06.storage.c-6.eu-central-1.aws.neon.tech
AWS_ACCESS_KEY_ID=nak_live_a9b075840ecf41de80f8f12939c49b58
AWS_SECRET_ACCESS_KEY=nsk_live_9b0ca4edd2247469c1549918c897fdcc4d8a0e8b984d2de43f0d50099293a735
AWS_REGION=eu-central-1
S3_BUCKET=uploads

ADMIN_PASSWORD_HASH=$2b$10$0Z8JfgSa1Nc1fO7MPmndxel/Iv0HaScYKtk94OZn3lz9yrwTgf3ki
JWT_SECRET=5b726d9b967e5c76c3c7f2848691c93f708b8907eb499417eee85a46d52977c2
NODE_ENV=production
```

4. **"Deploy"** tugmasini bosing.
5. Bir daqiqa ichida saytingiz va API tayyor bo'ladi:
   - **Landing Sahifasi:** `https://sizning-domen.vercel.app/`
   - **Admin Paneli:** `https://sizning-domen.vercel.app/admin`
   - **API Salomatlik Holati:** `https://sizning-domen.vercel.app/api/v1/health`

---

## 🛡️ Admin Boshqaruv Paneli (`/admin`)

- **Standart Parol:** `admin2026`
- **Imkoniyatlar:**
  1. **Statistika Metrikalari:** Jami masjidlar soni, tasdiqlanganlar, kutilayotgan arizalar va xatolik shikoyatlari soni.
  2. **Masjidlar Moderatsiyasi:** Har bir masjidni ko'rib chiqish, bir bosish bilan **Tasdiqlash** yoki **Rad etish**.
  3. **Yangi Masjid Qo'shish:** Nomi, koordinatalari, barcha qulayliklar belgilari va Neon S3 bulutiga fotosurat yuklash.
  4. **Foydalanuvchilar Shikoyatlari:** Yopilgan yoki xato kiritilgan joylarni tekshirish va hal etish.
  5. **OpenStreetMap Sinxronizatsiyasi:** Istalgan shahar (Toshkent, Samarqand, Istanbul, Dubay va b.) koordinatasini tanlab, OSM Overpass API orqali yuzlab masjidlarni avtomatik bazaga yuklash.

---

## 📱 Mobil Ilova (Android APK)

Ilova Android qurilmalar uchun to'liq yig'ilgan va `release/` hamda `backend/public/downloads/` kataloglariga joylashtirilgan.

### APK ni o'rnatish:
1. `release/Global_Masjid_Locator.apk` faylini telefoningizga o'tkazing (yoki landing sahifadagi "APK Yuklab Olish" orqali yuklang).
2. Faylni oching va "O'rnatish" tugmasini bosing.
3. Ilova GPS orqali birinchi soniyadayoq atrofingizdagi eng yaqin masjidlarni metr hisobida ko'rsatadi!

---

## 🧪 Sinov va Testlar

Backend testlarini ishga tushirish:
```bash
cd backend
npm test
```

Mobil ilovani statik analiz qilish:
```bash
cd mobile
flutter analyze
```

---

## 🤝 Litsenziya va Mualliflik

Loyiha butun dunyo musulmonlari uchun ochiq va bepul asosda yaratilgan.
OpenStreetMap® ma'lumotlari [ODbL](https://opendatacommons.org/licenses/odbl/) litsenziyasi asosida taqdim etiladi.
