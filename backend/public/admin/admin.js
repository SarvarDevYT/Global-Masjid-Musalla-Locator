document.addEventListener('DOMContentLoaded', () => {
  initAdmin();
});

let currentTab = 'mosques';

function initAdmin() {
  checkAuth();
  setupLoginForm();
  setupNav();
  setupFilters();
  setupAddMosqueForm();
  setupSyncForm();
}

// Check session
async function checkAuth() {
  try {
    const res = await fetch('/api/v1/admin/me');
    const data = await res.json();
    if (data.authenticated) {
      document.getElementById('login-overlay').style.display = 'none';
      loadDashboard();
    } else {
      document.getElementById('login-overlay').style.display = 'flex';
    }
  } catch (err) {
    document.getElementById('login-overlay').style.display = 'flex';
  }
}

// Setup Login
function setupLoginForm() {
  const form = document.getElementById('login-form');
  const errorBox = document.getElementById('login-error');

  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    errorBox.style.display = 'none';
    const password = document.getElementById('admin-password').value;

    try {
      const res = await fetch('/api/v1/admin/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ password })
      });
      const data = await res.json();

      if (data.success) {
        document.getElementById('login-overlay').style.display = 'none';
        loadDashboard();
      } else {
        errorBox.textContent = data.error || 'Parol noto\'g\'ri';
        errorBox.style.display = 'block';
      }
    } catch (err) {
      errorBox.textContent = 'Tarmoq xatosi';
      errorBox.style.display = 'block';
    }
  });

  document.getElementById('logout-btn').addEventListener('click', async () => {
    try {
      await fetch('/api/v1/admin/logout', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Requested-With': 'masjid-admin'
        }
      });
    } catch (_) {}
    window.location.reload();
  });
}

function loadDashboard() {
  loadStats();
  loadMosques();
}

// Navigation between tabs
function setupNav() {
  const items = document.querySelectorAll('.nav-item');
  items.forEach(item => {
    item.addEventListener('click', () => {
      items.forEach(i => i.classList.remove('active'));
      item.classList.add('active');
      currentTab = item.dataset.tab;

      document.querySelectorAll('.tab-content').forEach(c => c.style.display = 'none');
      const target = document.getElementById(`tab-${currentTab}`);
      if (target) target.style.display = 'block';

      if (currentTab === 'mosques') loadMosques();
      if (currentTab === 'reports') loadReports();
      if (currentTab === 'stats') loadStats();
    });
  });
}

// Load Stats
async function loadStats() {
  try {
    const res = await fetch('/api/v1/admin/stats');
    const json = await res.json();
    if (json.success && json.data) {
      const d = json.data;
      document.getElementById('stat-total').textContent = d.totalMosques ?? 0;
      document.getElementById('stat-pending').textContent = d.pending ?? 0;
      document.getElementById('stat-approved').textContent = d.approved ?? 0;
      document.getElementById('stat-reports').textContent = d.pendingReports ?? 0;
    }
  } catch (_) {}
}

// Setup Filters
function setupFilters() {
  const statusSelect = document.getElementById('filter-status');
  const searchInput = document.getElementById('search-mosque');

  if (statusSelect) {
    statusSelect.addEventListener('change', () => {
      loadMosques(statusSelect.value, searchInput.value);
    });
  }

  if (searchInput) {
    let timeout = null;
    searchInput.addEventListener('input', () => {
      clearTimeout(timeout);
      timeout = setTimeout(() => {
        loadMosques(statusSelect.value, searchInput.value);
      }, 300);
    });
  }
}

// Load Mosques Table
async function loadMosques(status = 'all', q = '') {
  const tbody = document.getElementById('mosques-tbody');
  if (!tbody) return;

  tbody.innerHTML = '<tr><td colspan="6" style="text-align:center; padding:30px; color:#9ca3af;">Yuklanmoqda...</td></tr>';

  try {
    const params = new URLSearchParams();
    if (status && status !== 'all') params.set('status', status);
    if (q) params.set('q', q);

    const res = await fetch(`/api/v1/admin/mosques?${params.toString()}`);
    const json = await res.json();

    if (!json.success || !Array.isArray(json.data) || json.data.length === 0) {
      tbody.innerHTML = '<tr><td colspan="6" style="text-align:center; padding:30px; color:#9ca3af;">Mos ma\'lumot topilmadi</td></tr>';
      return;
    }

    tbody.innerHTML = json.data.map(m => {
      const photoHtml = m.photo_url 
        ? `<img src="${m.photo_url}" alt="photo" style="width:42px; height:42px; border-radius:8px; object-fit:cover;">`
        : `<div style="width:42px; height:42px; border-radius:8px; background:rgba(255,255,255,0.05); display:flex; align-items:center; justify-content:center; font-size:1.2rem;">🕌</div>`;

      const badgeClass = m.status === 'approved' ? 'badge-approved' : (m.status === 'rejected' ? 'badge-rejected' : 'badge-pending');

      return `
        <tr>
          <td>${photoHtml}</td>
          <td>
            <strong>${escapeHtml(m.name || 'Masjid')}</strong>
            <br><small style="color:#9ca3af;">${escapeHtml(m.address || '')}</small>
          </td>
          <td>${escapeHtml(m.city || '')}, ${escapeHtml(m.country || '')}</td>
          <td>${escapeHtml(m.type === 'musalla' ? 'Namozxona' : 'Masjid')}</td>
          <td>
            <span class="badge ${badgeClass}">${m.status}</span>
          </td>
          <td>
            <div style="display:flex; gap:6px;">
              ${m.status !== 'approved' ? `
                <button type="button" class="btn btn-primary btn-sm" onclick="updateMosqueStatus('${m.id}', 'approved')">
                  ✓ Tasdiqlash
                </button>
              ` : ''}
              ${m.status !== 'rejected' ? `
                <button type="button" class="btn btn-danger btn-sm" onclick="updateMosqueStatus('${m.id}', 'rejected')">
                  ✕ Rad etish
                </button>
              ` : ''}
            </div>
          </td>
        </tr>
      `;
    }).join('');
  } catch (err) {
    tbody.innerHTML = '<tr><td colspan="6" style="text-align:center; padding:30px; color:#ef4444;">Xatolik yuz berdi</td></tr>';
  }
}

// Global update Mosque Status
window.updateMosqueStatus = async function(id, newStatus) {
  try {
    const res = await fetch(`/api/v1/admin/mosques/${id}/status`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'X-Requested-With': 'masjid-admin'
      },
      body: JSON.stringify({ status: newStatus })
    });
    const json = await res.json();
    if (json.success) {
      loadStats();
      const statusSelect = document.getElementById('filter-status');
      const searchInput = document.getElementById('search-mosque');
      loadMosques(statusSelect?.value, searchInput?.value);
    } else {
      alert(json.error || 'Xatolik');
    }
  } catch (err) {
    alert('Tarmoq xatosi');
  }
};

// Load User Reports
async function loadReports() {
  const tbody = document.getElementById('reports-tbody');
  if (!tbody) return;

  tbody.innerHTML = '<tr><td colspan="5" style="text-align:center; padding:30px; color:#9ca3af;">Yuklanmoqda...</td></tr>';

  try {
    const res = await fetch('/api/v1/admin/reports');
    const json = await res.json();

    if (!json.success || !Array.isArray(json.data) || json.data.length === 0) {
      tbody.innerHTML = '<tr><td colspan="5" style="text-align:center; padding:30px; color:#9ca3af;">Shikoyatlar mavjud emas</td></tr>';
      return;
    }

    tbody.innerHTML = json.data.map(r => {
      const dateStr = r.created_at ? new Date(r.created_at).toLocaleDateString() : '';
      return `
        <tr>
          <td><strong>${escapeHtml(r.mosque_name || r.mosque_id)}</strong></td>
          <td><span style="color:#f59e0b; font-weight:600;">${escapeHtml(r.reason)}</span></td>
          <td>${escapeHtml(r.details || '')}</td>
          <td><span class="badge ${r.status === 'reviewed' ? 'badge-approved' : 'badge-pending'}">${r.status}</span></td>
          <td>
            <div style="display:flex; gap:6px;">
              ${r.status === 'pending' ? `
                <button type="button" class="btn btn-primary btn-sm" onclick="updateReportStatus('${r.id}', 'reviewed')">
                  Ko'rib chiqildi
                </button>
                <button type="button" class="btn btn-secondary btn-sm" onclick="updateReportStatus('${r.id}', 'dismissed')">
                  Bekor qilish
                </button>
              ` : '<span style="color:#6b7280; font-size:0.8rem;">Yopilgan</span>'}
            </div>
          </td>
        </tr>
      `;
    }).join('');
  } catch (err) {
    tbody.innerHTML = '<tr><td colspan="5" style="text-align:center; padding:30px; color:#ef4444;">Xatolik yuz berdi</td></tr>';
  }
}

window.updateReportStatus = async function(id, newStatus) {
  try {
    const res = await fetch(`/api/v1/admin/reports/${id}`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'X-Requested-With': 'masjid-admin'
      },
      body: JSON.stringify({ status: newStatus })
    });
    if (res.ok) {
      loadStats();
      loadReports();
    }
  } catch (_) {}
};

// Add Mosque Form
function setupAddMosqueForm() {
  const form = document.getElementById('add-mosque-form');
  const locateBtn = document.getElementById('btn-get-current-pos');

  if (locateBtn) {
    locateBtn.addEventListener('click', () => {
      if (navigator.geolocation) {
        navigator.geolocation.getCurrentPosition(
          pos => {
            document.getElementById('input-lat').value = pos.coords.latitude.toFixed(6);
            document.getElementById('input-lng').value = pos.coords.longitude.toFixed(6);
          },
          () => alert('GPS ruxsati berilmadi.')
        );
      }
    });
  }

  if (form) {
    form.addEventListener('submit', async (e) => {
      e.preventDefault();
      const submitBtn = document.getElementById('btn-save-mosque');
      submitBtn.disabled = true;
      submitBtn.textContent = 'Saqlanmoqda...';

      try {
        let photoUrl = null;
        const photoFile = document.getElementById('input-photo').files[0];

        // Upload photo to Neon S3 if selected
        if (photoFile) {
          const formData = new FormData();
          formData.append('photo', photoFile);

          const upRes = await fetch('/api/v1/upload', {
            method: 'POST',
            body: formData
          });
          const upJson = await upRes.json();
          if (upJson.success && upJson.url) {
            photoUrl = upJson.url;
          }
        }

        const payload = {
          name: document.getElementById('input-name').value.trim(),
          alt_name: document.getElementById('input-alt-name').value.trim() || undefined,
          address: document.getElementById('input-address').value.trim(),
          city: document.getElementById('input-city').value.trim(),
          country: document.getElementById('input-country').value.trim() || "O'zbekiston",
          type: document.getElementById('input-type').value,
          lat: parseFloat(document.getElementById('input-lat').value),
          lng: parseFloat(document.getElementById('input-lng').value),
          has_wudu_men: document.getElementById('check-wudu-men').checked,
          has_wudu_women: document.getElementById('check-wudu-women').checked,
          has_women_prayer_area: document.getElementById('check-women-prayer').checked,
          has_juma: document.getElementById('check-juma').checked,
          has_wheelchair_access: document.getElementById('check-wheelchair').checked,
          has_parking: document.getElementById('check-parking').checked,
          photo_url: photoUrl || undefined
        };

        const res = await fetch('/api/v1/mosques/contribute', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload)
        });

        const json = await res.json();
        if (json.success) {
          alert('Masjid muvaffaqiyatli qo\'shildi!');
          form.reset();
          loadStats();
          document.querySelector('[data-tab="mosques"]').click();
        } else {
          alert(json.error || 'Qo\'shishda xatolik yuz berdi');
        }
      } catch (err) {
        alert('Tarmoq xatosi: ' + err.message);
      } finally {
        submitBtn.disabled = false;
        submitBtn.textContent = 'Masjidni Saqlash';
      }
    });
  }
}

// OpenStreetMap Overpass Sync Form
function setupSyncForm() {
  const form = document.getElementById('sync-form');
  const syncBtn = document.getElementById('btn-sync-submit');
  const syncResult = document.getElementById('sync-result');

  // Preset buttons
  document.querySelectorAll('.sync-preset-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      document.getElementById('sync-lat').value = btn.dataset.lat;
      document.getElementById('sync-lng').value = btn.dataset.lng;
    });
  });

  if (form) {
    form.addEventListener('submit', async (e) => {
      e.preventDefault();
      syncBtn.disabled = true;
      syncBtn.textContent = 'OpenStreetMap dan yuklanmoqda...';
      syncResult.style.display = 'none';

      const payload = {
        lat: parseFloat(document.getElementById('sync-lat').value),
        lng: parseFloat(document.getElementById('sync-lng').value),
        radius: parseInt(document.getElementById('sync-radius').value, 10)
      };

      try {
        const res = await fetch('/api/v1/admin/sync/overpass', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-Requested-With': 'masjid-admin'
          },
          body: JSON.stringify(payload)
        });
        const json = await res.json();

        if (json.success) {
          syncResult.style.display = 'block';
          syncResult.className = 'sync-success-box';
          syncResult.innerHTML = `
            <strong>Muvaffaqiyatli yakunlandi!</strong><br>
            Topilgan jami masjidlar: ${json.totalFetched}<br>
            Bazaga yangi kiritilganlar: ${json.newlyInserted}
          `;
          loadStats();
        } else {
          syncResult.style.display = 'block';
          syncResult.className = 'sync-error-box';
          syncResult.textContent = json.error || 'Import xatosi';
        }
      } catch (err) {
        syncResult.style.display = 'block';
        syncResult.className = 'sync-error-box';
        syncResult.textContent = 'Server bilan aloqa uzildi';
      } finally {
        syncBtn.disabled = false;
        syncBtn.textContent = 'Importni Boshlash';
      }
    });
  }
}

function escapeHtml(str) {
  const div = document.createElement('div');
  div.textContent = str;
  return div.innerHTML;
}
