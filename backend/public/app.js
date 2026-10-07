document.addEventListener('DOMContentLoaded', () => {
  initHealthCheck();
  initLiveDemo();
  initQrCode();
});

// Preset Cities coordinates
const PRESETS = {
  tashkent: { name: 'Toshkent (Hazrati Imom)', lat: 41.3364, lng: 69.2398 },
  samarkand: { name: 'Samarqand (Registon)', lat: 39.6547, lng: 66.9758 },
  bukhara: { name: 'Buxoro (Poi Kalon)', lat: 39.7758, lng: 64.4150 },
  istanbul: { name: 'Istanbul (Sultanahmet)', lat: 41.0054, lng: 28.9768 },
  mecca: { name: 'Makkah (Al-Haram)', lat: 21.4225, lng: 39.8262 }
};

let currentCoords = PRESETS.tashkent;
let mosquesData = [];

// Real-time server health status
async function initHealthCheck() {
  const statusText = document.getElementById('server-status-text');
  const statusDot = document.getElementById('server-status-dot');
  if (!statusText || !statusDot) return;

  try {
    const res = await fetch('/api/v1/health');
    if (res.ok) {
      const data = await res.json();
      statusText.textContent = data.postgresConnected ? 'Server & Neon DB: Faol' : 'Server: Faol (Kesh)';
      statusDot.style.background = '#10b981';
      statusDot.style.boxShadow = '0 0 8px #10b981';
    } else {
      statusText.textContent = 'Server: Aloqa sekin';
      statusDot.style.background = '#f59e0b';
    }
  } catch (err) {
    statusText.textContent = 'Server: Oflayn';
    statusDot.style.background = '#ef4444';
  }
}

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
            alert('GPS ruxsati olinmadi. Shaharlardan birini tanlashingiz mumkin.');
            locateBtn.textContent = '📍 GPS Orqali Aniqlash';
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

  // Initial fetch
  fetchNearbyMosques();
}

async function fetchNearbyMosques() {
  const container = document.getElementById('demo-results');
  if (!container) return;

  container.innerHTML = `
    <div style="grid-column: 1/-1; text-align: center; padding: 40px; color: var(--text-muted);">
      <div style="display: inline-block; width: 28px; height: 28px; border: 3px solid rgba(16,185,129,0.3); border-top-color: #10b981; border-radius: 50%; animation: spin 1s linear infinite;"></div>
      <p style="margin-top: 12px; font-size: 0.9rem;">Yaqin atrofdagi masjidlar qidirilmoqda...</p>
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
        <div style="grid-column: 1/-1; text-align: center; padding: 40px; color: var(--text-muted);">
          <p>Ushbu hudud bo'yicha masjidlar topilmadi.</p>
        </div>
      `;
    }
  } catch (err) {
    container.innerHTML = `
      <div style="grid-column: 1/-1; text-align: center; padding: 40px; color: var(--text-dim);">
        <p>Ma'lumotlarni yuklashda xatolik yuz berdi.</p>
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
      <div style="grid-column: 1/-1; text-align: center; padding: 40px; color: var(--text-muted);">
        <p>Qidiruv natijasida masjid topilmadi.</p>
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
            <span class="mosque-card-dist">${distText}</span>
          </div>
          <p class="mosque-card-addr">${escapeHtml(m.address || m.city || 'Aniq manzil ko\'rsatilmagan')}</p>
          <div class="mosque-tags">
            <span class="mosque-tag ${m.has_wudu_men ? 'has' : ''}">
              💧 Tahoratxona (${m.has_wudu_women ? 'Erkak/Ayol' : 'Erkaklar'})
            </span>
            ${m.has_women_prayer_area ? '<span class="mosque-tag has">🧕 Ayollar zali</span>' : ''}
            ${m.has_juma ? '<span class="mosque-tag has">🕌 Juma o\'qiladi</span>' : ''}
            ${m.has_parking ? '<span class="mosque-tag has">🚗 Parking</span>' : ''}
          </div>
        </div>
        <div class="mosque-card-actions">
          <span style="font-size: 0.75rem; color: var(--text-dim);">${escapeHtml(m.type === 'musalla' ? 'Namozxona' : 'Jome Masjid')}</span>
          <a href="${mapsUrl}" target="_blank" rel="noopener noreferrer" class="btn btn-secondary btn-sm" style="font-size: 0.78rem;">
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

// Generate simple SVG QR Code for downloading APK
function initQrCode() {
  const qrWrapper = document.getElementById('qr-canvas-container');
  if (!qrWrapper) return;

  // Aesthetic SVG QR pattern representation
  qrWrapper.innerHTML = `
    <svg width="160" height="160" viewBox="0 0 160 160" fill="none" xmlns="http://www.w3.org/2000/svg">
      <rect width="160" height="160" fill="white"/>
      <!-- QR Position Markers -->
      <rect x="10" y="10" width="40" height="40" rx="6" fill="#111827"/>
      <rect x="18" y="18" width="24" height="24" rx="3" fill="white"/>
      <rect x="23" y="23" width="14" height="14" rx="2" fill="#047857"/>

      <rect x="110" y="10" width="40" height="40" rx="6" fill="#111827"/>
      <rect x="118" y="18" width="24" height="24" rx="3" fill="white"/>
      <rect x="123" y="23" width="14" height="14" rx="2" fill="#047857"/>

      <rect x="10" y="110" width="40" height="40" rx="6" fill="#111827"/>
      <rect x="18" y="118" width="24" height="24" rx="3" fill="white"/>
      <rect x="23" y="123" width="14" height="14" rx="2" fill="#047857"/>

      <!-- Data Dots -->
      <rect x="60" y="15" width="10" height="10" rx="2" fill="#111827"/>
      <rect x="75" y="15" width="10" height="10" rx="2" fill="#111827"/>
      <rect x="90" y="25" width="10" height="10" rx="2" fill="#10b981"/>
      <rect x="60" y="35" width="10" height="10" rx="2" fill="#111827"/>
      <rect x="80" y="45" width="10" height="10" rx="2" fill="#111827"/>

      <rect x="15" y="60" width="10" height="10" rx="2" fill="#111827"/>
      <rect x="35" y="65" width="10" height="10" rx="2" fill="#10b981"/>
      <rect x="20" y="80" width="10" height="10" rx="2" fill="#111827"/>
      <rect x="35" y="95" width="10" height="10" rx="2" fill="#111827"/>

      <rect x="60" y="60" width="40" height="40" rx="8" fill="#10b981"/>
      <path d="M73 80L78 85L87 75" stroke="white" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>

      <rect x="110" y="60" width="10" height="10" rx="2" fill="#111827"/>
      <rect x="125" y="75" width="10" height="10" rx="2" fill="#111827"/>
      <rect x="140" y="65" width="10" height="10" rx="2" fill="#111827"/>
      <rect x="115" y="90" width="10" height="10" rx="2" fill="#10b981"/>

      <rect x="60" y="110" width="10" height="10" rx="2" fill="#111827"/>
      <rect x="80" y="115" width="10" height="10" rx="2" fill="#111827"/>
      <rect x="70" y="130" width="10" height="10" rx="2" fill="#10b981"/>
      <rect x="90" y="140" width="10" height="10" rx="2" fill="#111827"/>
      <rect x="115" y="120" width="10" height="10" rx="2" fill="#111827"/>
      <rect x="135" y="135" width="10" height="10" rx="2" fill="#111827"/>
    </svg>
  `;
}
