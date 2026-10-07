# Global Masjid & Musalla Locator (Mobil Ilova & PostGIS Backend)

Butun dunyo bo‘ylab musulmonlar va sayohatchilar uchun mo‘ljallangan, yuqori tezlikda ishlovchi cross-platform mobil ilova (iOS & Android) hamda geofazoviy Neon PostgreSQL (PostGIS) backend tizimi.

---

## 🏗 Loyiha Strukturasi

```
Global Masjid & Musalla Locator/
├── backend/                       # Node.js + Express + Neon PostGIS Server
│   ├── src/
│   │   ├── config/                # Server & Muhit konfiguratsiyalari
│   │   ├── db/                    # PostGIS schema.sql, migratsiyalar, urug' ma'lumotlari (seeds)
│   │   ├── middleware/            # Xavfsizlik (Helmet, Rate Limiting), Zod validatsiyasi, Error handler
│   │   ├── routes/                # Masjidlar (/nearby, /contribute, /report) va OSM sync (/sync/overpass)
│   │   ├── services/              # OpenStreetMap Overpass API integratsiyasi
│   │   ├── app.js                 # Express ilova sozlamalari
│   │   └── server.js              # Serverni ishga tushirish
│   ├── tests/                     # Haversine, geofazoviy saralash va API testlari
│   └── package.json
│
└── mobile/                        # Flutter Mobil Ilovasi (iOS & Android)
    ├── lib/
    │   ├── core/
    │   │   ├── constants/         # AppColors, ApiConstants
    │   │   ├── l10n/              # 5 ta tilda lokalizatsiya (UZ, EN, RU, AR, TR)
    │   │   ├── theme/             # Material 3 Light & Dark mavzular
    │   │   └── utils/             # Haversine, Qibla hisoblash formulalari, Tashqi xaritalar launcher
    │   ├── data/
    │   │   ├── models/            # MosqueModel
    │   │   ├── repositories/      # Offline kesh (SharedPreferences) + API Repository
    │   │   └── services/          # Geolocator, HTTP API va Overpass fallback
    │   ├── providers/             # Riverpod State Notifiers (Location, Filters, Mosques, Theme, Locale)
    │   ├── ui/
    │   │   ├── screens/           # HomeScreen (Split View), QiblaScreen, AddMosqueScreen, SettingsScreen
    │   │   └── widgets/           # MapWidget, MosqueCard, DetailSheet, AmenityChip, SkeletonLoader
    │   └── main.dart              # Mobil ilova boshlang'ich nuqtasi
    └── pubspec.yaml
```

---

## ⚡ Neon Database (PostgreSQL + PostGIS) Bilan Ishlash

Neon serverless PostgreSQL xizmati PostGIS kengaytmasini to'liq qo'llab-quvvatlaydi.

### 1-qadam: Neon loyihasini yaratish
1. [Neon Console](https://console.neon.tech) oynasida loyiha nomini tanlang (masalan, `Masjid Locator`).
2. **Region:** `AWS Europe Central 1 (Frankfurt)`
3. **"Create project"** oq tugmasini bosing.

### 2-qadam: Connection Stringni `.env` faylga kiritish
Neon loyiha yaratilgandan so'ng ekranda `Connection string` chiqadi. Uni nusxalab oling:
```env
postgresql://neondb_owner:npg_xxxx@ep-xyz-123456.eu-central-1.aws.neon.tech/neondb?sslmode=require
```

`backend` papkasidagi `.env` faylini oching va unga quyidagini yozing:
```env
DATABASE_URL=postgresql://neondb_owner:npg_xxxx@ep-xyz-123456.eu-central-1.aws.neon.tech/neondb?sslmode=require
PORT=3000
NODE_ENV=development
```

### 3-qadam: PostGIS sxemasini va dastlabki masjidlarni Neon bazasiga yuklash
Terminalda `backend` papkasiga o'tib, bitta buyruqni ishga tushiring:
```bash
cd backend
npm run migrate
```
Bu avtomatik ravishda:
- `CREATE EXTENSION postgis;` ni yoqadi
- `mosques` va `mosque_reports` jadvallarini yaratadi
- Geofazoviy `SP-GIST` indeksini o'rnatadi
- Boshlang'ich masjidlar ma'lumotlarini Neon bazasiga yuklaydi.

### 4-qadam: Backend Serverni ishga tushirish
```bash
npm run dev
```
Server `http://localhost:3000` portida ishga tushadi:
- **Salomatlik tekshiruvi:** `GET http://localhost:3000/api/v1/health`
- **Yaqin masjidlar:** `GET http://localhost:3000/api/v1/mosques/nearby?lat=41.3381&lng=69.2415&radius=10000`

---

## 📱 Flutter Mobil Ilovasini Ishga Tushirish

Mobil ilova to'liq cross-platform (Android, iOS, Web, Windows).

```bash
cd mobile
flutter run
```

Yoki brauzerda sinab ko'rish uchun:
```bash
flutter run -d chrome
```

---

## 🕌 Asosiy Imkoniyatlar va Funksiyalar

1. **Avtomatik Geolokatsiya va Masofa Dvigateli (Core):**
   - GPS ochilganda real masofani hisoblaydi (< 1 km bo'lsa metrda `350 m`, oshsa `2.4 km`).
   - Eng yaqinidan uzog'iga tartiblash (Ascending sort).
   - Xarita surilganda **"Ushbu hududdan qidirish"** tugmasi orqali yangi markaz bo'yicha tezkor qidiruv.
2. **Qulaylik Filtrlari (Amenities):**
   - Tahoratxona (Erkaklar / Ayollar)
   - Ayollar namozxonasi
   - Juma namozi bor/yo'qligi
   - Nogironlar aravachasi (Wheelchair accessibility)
   - Avtoturargoh (Parking)
3. **Tashqi Navigatsiya Integratsiyasi:**
   - "Borish" tugmasi bosilganda: Google Maps, Apple Maps, Yandex Maps, 2GIS va Waze tanlov oynasi.
4. **Oflayn Rejim va Qibla Kompasi:**
   - 15-30 km radiusdagi masjidlar lokal keshlanadi va internet o'chganda ham oflayn GPS orqali masofani hisoblab turadi.
   - Magnetometer sensori orqali real vaqtda Ka'baga yo'naltiruvchi o'rnatilgan **Qibla Kompasi**.
5. **Crowdsourcing va Jamiyat Tahriri:**
   - Yangi masjid yoki namozxona qo'shish ekrani (status: `pending`).
   - Xato ma'lumotlar ustidan shikoyat yuborish (Report modal).
6. **Zamonaviy UI/UX:**
   - Split View (Yuqorida OpenStreetMap, pastda suriluvchi Draggable Sheet).
   - Skeleton Loaderlar.
   - Dark / Light rejimi.
   - 5 ta tilda to'liq qo'llab-quvvatlash (O'zbek, Ingliz, Rus, Arab, Turk).
