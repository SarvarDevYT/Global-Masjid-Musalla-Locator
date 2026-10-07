document.addEventListener('DOMContentLoaded', () => {
  initLiveDemo();
  initQrCode();
});

// Preset Cities coordinates for quick demo exploration
const PRESETS = {
  tashkent: { name: 'Toshkent (Hazrati Imom)', lat: 41.3364, lng: 69.2398 },
  samarkand: { name: 'Samarqand (Registon)', lat: 39.6547, lng: 66.9758 },
  bukhara: { name: 'Buxoro (Poi Kalon)', lat: 39.7758, lng: 64.4150 },
  istanbul: { name: 'Istanbul (Sultanahmet)', lat: 41.0054, lng: 28.9768 },
  mecca: { name: 'Makkah (Al-Haram)', lat: 21.4225, lng: 39.8262 },
  medina: { name: 'Madina (Masjid an-Nabawi)', lat: 24.4672, lng: 39.6111 }
};

let currentCoords = PRESETS.tashkent;
let mosquesData = [];

// Live Interactive Mosque Finder Demo
function initLiveDemo() {
  const locateBtn = document.getElementById('btn-gps-locate');
  const searchInput = document.getElementById('demo-search');
  const pillBtns = document.querySelectorAll('.pill-btn');

  if (locateBtn) {
    locateBtn.addEventListener('click', () => {
      if (navigator.geolocation) {
        locateBtn.textContent = 'GPS Aniqlanmoqda...';
        navigator.geolocation.getCurrentPosition(
          (pos) => {
            currentCoords = {
              name: 'Sizning joylashuvingiz',
              lat: pos.coords.latitude,
              lng: pos.coords.longitude
            };
            locateBtn.textContent = '📍 Mening Joylashuvim';
            pillBtns.forEach(p => p.classList.remove('active'));
            fetchNearbyMosques();
          },
          (err) => {
            alert('GPS ruxsati olinmadi. Ro\'yxatdagi shaharlardan birini tanlashingiz mumkin.');
            locateBtn.textContent = '📍 Joylashuvimni Aniqlash';
          },
          { timeout: 8000 }
        );
      } else {
        alert('Brauzeringiz GPS-ni qo\'llab-quvvatlamaydi.');
      }
    });
  }

  pillBtns.forEach((btn) => {
    btn.addEventListener('click', () => {
      pillBtns.forEach(p => p.classList.remove('active'));
      btn.classList.add('active');
      const key = btn.dataset.preset;
      if (PRESETS[key]) {
        currentCoords = PRESETS[key];
        fetchNearbyMosques();
      }
    });
  });

  if (searchInput) {
    searchInput.addEventListener('input', (e) => {
      filterAndRenderMosques(e.target.value.trim().toLowerCase());
    });
  }

  // Initial fetch for Tashkent
  fetchNearbyMosques();
}

async function fetchNearbyMosques() {
  const container = document.getElementById('demo-results');
  if (!container) return;

  container.innerHTML = `
    <div style="grid-column: 1/-1; text-align: center; padding: 48px; color: var(--text-silver);">
      <div style="display: inline-block; width: 32px; height: 32px; border: 3px solid rgba(52,211,153,0.25); border-top-color: #34d399; border-radius: 50%; animation: spin 1s linear infinite;"></div>
      <p style="margin-top: 14px; font-size: 0.95rem; font-weight: 600;">Yaqin atrofdagi masjidlar qidirilmoqda...</p>
    </div>
  `;

  try {
    const url = `/api/v1/mosques/nearby?lat=${currentCoords.lat}&lng=${currentCoords.lng}&radius=20000`;
    const res = await fetch(url);
    const result = await res.json();

    if (result.success && Array.isArray(result.data)) {
      mosquesData = result.data;
      filterAndRenderMosques('');
    } else {
      container.innerHTML = `
        <div style="grid-column: 1/-1; text-align: center; padding: 48px; color: var(--text-muted);">
          <p>Ushbu hudud bo'yicha masjidlar topilmadi.</p>
        </div>
      `;
    }
  } catch (err) {
    container.innerHTML = `
      <div style="grid-column: 1/-1; text-align: center; padding: 48px; color: var(--text-muted);">
        <p>Ma'lumotlarni yuklashda vaqtinchalik uzilish yuz berdi. Iltimos qayta urinib ko'ring.</p>
      </div>
    `;
  }
}

function filterAndRenderMosques(keyword) {
  const container = document.getElementById('demo-results');
  if (!container) return;

  const filtered = mosquesData.filter(m => {
    if (!keyword) return true;
    const name = (m.name || '').toLowerCase();
    const city = (m.city || '').toLowerCase();
    const addr = (m.address || '').toLowerCase();
    return name.includes(keyword) || city.includes(keyword) || addr.includes(keyword);
  });

  if (filtered.length === 0) {
    container.innerHTML = `
      <div style="grid-column: 1/-1; text-align: center; padding: 48px; color: var(--text-muted);">
        <p>Qidiruv so'rovi bo'yicha masjid topilmadi.</p>
      </div>
    `;
    return;
  }

  container.innerHTML = filtered.slice(0, 6).map(m => {
    const distText = m.distance != null 
      ? (m.distance < 1000 ? `${m.distance} m` : `${(m.distance / 1000).toFixed(1)} km`)
      : 'Yaqin';

    const mapsUrl = `https://www.google.com/maps/dir/?api=1&destination=${m.latitude},${m.longitude}`;

    return `
      <div class="mosque-card">
        <div>
          <div class="mosque-card-head">
            <h4 class="mosque-card-name">${escapeHtml(m.name || 'Masjid')}</h4>
            <span class="mosque-card-dist">📍 ${distText}</span>
          </div>
          <p class="mosque-card-addr">${escapeHtml(m.address || m.city || 'Aniq manzil ilovada mavjud')}</p>
          <div class="mosque-tags">
            <span class="mosque-tag ${m.has_wudu_men ? 'has' : ''}">
              💧 Tahoratxona (${m.has_wudu_women ? 'Erkak/Ayol' : 'Erkaklar'})
            </span>
            ${m.has_women_prayer_area ? '<span class="mosque-tag has">🧕 Ayollar zali bor</span>' : ''}
            ${m.has_juma ? '<span class="mosque-tag has">🕌 Juma o\'qiladi</span>' : ''}
            ${m.has_parking ? '<span class="mosque-tag has">🚗 Avtoturargoh</span>' : ''}
          </div>
        </div>
        <div class="mosque-card-actions">
          <span style="font-size: 0.78rem; color: var(--text-muted); font-weight: 600;">
            ${escapeHtml(m.type === 'musalla' ? 'Namozxona' : 'Jome Masjidi')}
          </span>
          <a href="${mapsUrl}" target="_blank" rel="noopener noreferrer" class="btn btn-secondary btn-sm" style="font-size: 0.8rem; padding: 7px 14px;">
            🗺️ Xaritada Ko'rish
          </a>
        </div>
      </div>
    `;
  }).join('');
}

function escapeHtml(str) {
  const div = document.createElement('div');
  div.textContent = str;
  return div.innerHTML;
}

// Crisp Vector QR Code for Direct Phone Download
function initQrCode() {
  const qrWrapper = document.getElementById('qr-canvas-container');
  if (!qrWrapper) return;

  qrWrapper.innerHTML = `
    <svg width="170" height="170" viewBox="0 0 160 160" fill="none" xmlns="http://www.w3.org/2000/svg">
      <rect width="160" height="160" rx="8" fill="white"/>
      <!-- Outer Positioning Rings -->
      <rect x="12" y="12" width="38" height="38" rx="7" fill="#047857"/>
      <rect x="18" y="18" width="26" height="26" rx="4" fill="white"/>
      <rect x="23" y="23" width="16" height="16" rx="3" fill="#047857"/>

      <rect x="110" y="12" width="38" height="38" rx="7" fill="#047857"/>
      <rect x="116" y="18" width="26" height="26" rx="4" fill="white"/>
      <rect x="121" y="23" width="16" height="16" rx="3" fill="#047857"/>

      <rect x="12" y="110" width="38" height="38" rx="7" fill="#047857"/>
      <rect x="18" y="116" width="26" height="26" rx="4" fill="white"/>
      <rect x="23" y="121" width="16" height="16" rx="3" fill="#047857"/>

      <!-- Matrix Patterns -->
      <rect x="58" y="14" width="10" height="10" rx="2" fill="#064e3b"/>
      <rect x="74" y="14" width="10" height="10" rx="2" fill="#064e3b"/>
      <rect x="90" y="24" width="10" height="10" rx="2" fill="#10b981"/>
      <rect x="58" y="34" width="10" height="10" rx="2" fill="#064e3b"/>
      <rect x="78" y="44" width="10" height="10" rx="2" fill="#064e3b"/>

      <rect x="16" y="60" width="10" height="10" rx="2" fill="#064e3b"/>
      <rect x="36" y="64" width="10" height="10" rx="2" fill="#10b981"/>
      <rect x="20" y="80" width="10" height="10" rx="2" fill="#064e3b"/>
      <rect x="36" y="94" width="10" height="10" rx="2" fill="#064e3b"/>

      <!-- Center App Emblem inside QR -->
      <rect x="58" y="58" width="44" height="44" rx="10" fill="#059669"/>
      <path d="M72 80L78 86L88 74" stroke="white" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round"/>

      <rect x="110" y="60" width="10" height="10" rx="2" fill="#064e3b"/>
      <rect x="126" y="74" width="10" height="10" rx="2" fill="#064e3b"/>
      <rect x="138" y="64" width="10" height="10" rx="2" fill="#064e3b"/>
      <rect x="116" y="90" width="10" height="10" rx="2" fill="#10b981"/>

      <rect x="58" y="112" width="10" height="10" rx="2" fill="#064e3b"/>
      <rect x="78" y="116" width="10" height="10" rx="2" fill="#064e3b"/>
      <rect x="68" y="132" width="10" height="10" rx="2" fill="#10b981"/>
      <rect x="90" y="140" width="10" height="10" rx="2" fill="#064e3b"/>
      <rect x="114" y="122" width="10" height="10" rx="2" fill="#064e3b"/>
      <rect x="134" y="136" width="10" height="10" rx="2" fill="#064e3b"/>
    </svg>
  `;
}
