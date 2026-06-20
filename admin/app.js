const STORAGE_KEY = 'famplans_admin_session';

let supabase = null;
let currentTab = 'customers';
let selectedFamilyId = null;

function getConfig() {
  return window.FAMPLANS_ADMIN_CONFIG ?? null;
}

function formatDate(value) {
  if (!value) return '—';
  return new Date(value).toLocaleString();
}

function show(el) {
  el.classList.remove('hidden');
}

function hide(el) {
  el.classList.add('hidden');
}

function setMessage(el, text, type = 'error') {
  if (!text) {
    hide(el);
    el.textContent = '';
    return;
  }
  el.textContent = text;
  el.className = type;
  show(el);
}

function showBootError(message) {
  const login = document.getElementById('login-screen');
  show(login);
  hide(document.getElementById('setup-screen'));
  hide(document.getElementById('dashboard-screen'));
  setMessage(document.getElementById('login-message'), message);
}

async function initSupabase() {
  try {
    const config = getConfig();
    const hasValidKey =
      config?.supabaseAnonKey &&
      config.supabaseAnonKey !== 'your-anon-key-here';

    if (!config?.supabaseUrl || !hasValidKey) {
      show(document.getElementById('setup-screen'));
      hide(document.getElementById('login-screen'));
      hide(document.getElementById('dashboard-screen'));
      return false;
    }

    if (!window.supabase?.createClient) {
      showBootError(
        'Could not load Supabase. Check your internet connection and refresh.',
      );
      return false;
    }

    supabase = window.supabase.createClient(
      config.supabaseUrl,
      config.supabaseAnonKey,
    );

    const saved = localStorage.getItem(STORAGE_KEY);
    if (saved) {
      try {
        const session = JSON.parse(saved);
        const { error } = await supabase.auth.setSession(session);
        if (!error) {
          await showDashboard();
          return true;
        }
      } catch {
        // Ignore corrupt saved sessions.
      }
      localStorage.removeItem(STORAGE_KEY);
    }

    show(document.getElementById('login-screen'));
    hide(document.getElementById('setup-screen'));
    hide(document.getElementById('dashboard-screen'));
    return true;
  } catch (error) {
    showBootError(error.message ?? 'Could not start the admin app. Refresh and try again.');
    return false;
  }
}

async function saveSetup(event) {
  event.preventDefault();
  const url = document.getElementById('setup-url').value.trim();
  const key = document.getElementById('setup-key').value.trim();
  const message = document.getElementById('setup-message');

  if (!url || !key) {
    setMessage(message, 'Enter both Supabase URL and anon key.');
    return;
  }

  window.FAMPLANS_ADMIN_CONFIG = {
    supabaseUrl: url,
    supabaseAnonKey: key,
  };

  localStorage.setItem(
    'famplans_admin_config',
    JSON.stringify(window.FAMPLANS_ADMIN_CONFIG),
  );

  await initSupabase();
}

function loadSavedConfig() {
  const saved = localStorage.getItem('famplans_admin_config');
  if (saved && !window.FAMPLANS_ADMIN_CONFIG) {
    window.FAMPLANS_ADMIN_CONFIG = JSON.parse(saved);
  }
}

let otpState = { pinId: null, phone: null };

async function sendOtp(event) {
  event.preventDefault();
  const phone = document.getElementById('phone').value.trim();
  const message = document.getElementById('login-message');
  const sendBtn = document.getElementById('send-code-btn');

  sendBtn.disabled = true;
  setMessage(message, '');

  try {
    const { data, error } = await supabase.functions.invoke('send-otp', {
      body: { phone },
    });

    if (error) throw error;
    if (data?.error) throw new Error(data.error);

    otpState = { pinId: data.pin_id, phone: data.phone ?? phone };
    document.getElementById('otp-section').classList.remove('hidden');
    document.getElementById('otp-phone-label').textContent =
      `Code sent to ${otpState.phone}`;
    setMessage(message, 'Verification code sent.', 'success');
  } catch (error) {
    setMessage(message, error.message ?? 'Could not send code.');
  } finally {
    sendBtn.disabled = false;
  }
}

async function verifyOtp(event) {
  event.preventDefault();
  const pin = document.getElementById('otp').value.trim();
  const message = document.getElementById('login-message');
  const verifyBtn = document.getElementById('verify-code-btn');

  if (!otpState.pinId || !otpState.phone) {
    setMessage(message, 'Send a code first.');
    return;
  }

  verifyBtn.disabled = true;
  setMessage(message, '');

  try {
    const { data, error } = await supabase.functions.invoke('verify-otp', {
      body: {
        phone: otpState.phone,
        pin_id: otpState.pinId,
        pin,
      },
    });

    if (error) throw error;
    if (data?.error) throw new Error(data.error);

    const { error: sessionError } = await supabase.auth.setSession({
      access_token: data.access_token,
      refresh_token: data.refresh_token,
    });

    if (sessionError) throw sessionError;

    localStorage.setItem(
      STORAGE_KEY,
      JSON.stringify({
        access_token: data.access_token,
        refresh_token: data.refresh_token,
      }),
    );

    await showDashboard();
  } catch (error) {
    setMessage(message, error.message ?? 'Could not verify code.');
  } finally {
    verifyBtn.disabled = false;
  }
}

async function adminRequest(action, extra = {}) {
  const { data, error } = await supabase.functions.invoke('admin-data', {
    body: { action, ...extra },
  });

  if (error) throw error;
  if (data?.error) throw new Error(data.error);
  return data;
}

async function showDashboard() {
  hide(document.getElementById('setup-screen'));
  hide(document.getElementById('login-screen'));
  show(document.getElementById('dashboard-screen'));

  try {
    await refreshAll();
  } catch (error) {
    if ((error.message ?? '').includes('operator admin')) {
      await signOut();
      setMessage(
        document.getElementById('login-message'),
        'This account is not a platform admin. Ask support to enable your profile.',
      );
      return;
    }
    setMessage(document.getElementById('dashboard-message'), error.message);
  }
}

async function refreshAll() {
  const stats = await adminRequest('stats');
  document.getElementById('stat-users').textContent = stats.total_users;
  document.getElementById('stat-families').textContent = stats.total_families;
  document.getElementById('stat-new-users').textContent = stats.new_users_7d;
  document.getElementById('stat-members').textContent = stats.active_members;

  await renderCustomers();
  await renderFamilies();
}

async function renderCustomers() {
  const { customers } = await adminRequest('customers');
  const tbody = document.getElementById('customers-body');
  tbody.innerHTML = customers
    .map((customer) => {
      const families = customer.families?.length
        ? customer.families
            .map((f) => `${f.family_name} (${f.role})`)
            .join('<br>')
        : '<span class="muted">No family yet</span>';

      return `<tr>
        <td>${customer.display_name || '—'}</td>
        <td>${customer.phone || '—'}</td>
        <td>${customer.contact_email || '<span class="muted">—</span>'}</td>
        <td>${families}</td>
        <td>${formatDate(customer.created_at)}</td>
      </tr>`;
    })
    .join('');
}

async function renderFamilies() {
  const { families } = await adminRequest('families');
  const tbody = document.getElementById('families-body');
  tbody.innerHTML = families
    .map((family) => {
      const admins = family.admin_names?.join(', ') || '—';
      return `<tr>
        <td><button class="button secondary" data-family-id="${family.id}">${family.name}</button></td>
        <td>${family.member_count}</td>
        <td>${admins}</td>
        <td><code>${family.invite_code || '—'}</code></td>
        <td>${formatDate(family.created_at)}</td>
      </tr>`;
    })
    .join('');

  tbody.querySelectorAll('[data-family-id]').forEach((button) => {
    button.addEventListener('click', async () => {
      selectedFamilyId = button.dataset.familyId;
      await showFamilyDetail(selectedFamilyId);
    });
  });
}

async function showFamilyDetail(familyId) {
  const panel = document.getElementById('family-detail');
  const data = await adminRequest('family', { family_id: familyId });

  panel.innerHTML = `
    <h3>${data.family.name}</h3>
    <p class="muted">Invite code: <code>${data.family.invite_code ?? '—'}</code> · Tasks: ${data.task_count} · Events: ${data.event_count}</p>
    <table>
      <thead>
        <tr>
          <th>Name</th>
          <th>Phone</th>
          <th>Email</th>
          <th>Role</th>
          <th>Joined</th>
        </tr>
      </thead>
      <tbody>
        ${data.members
          .map((member) => {
            const profile = member.profiles ?? {};
            return `<tr>
              <td>${profile.display_name || '—'}</td>
              <td>${profile.phone || '—'}</td>
              <td>${profile.contact_email || '—'}</td>
              <td><span class="pill">${member.role}</span></td>
              <td>${formatDate(member.joined_at)}</td>
            </tr>`;
          })
          .join('')}
      </tbody>
    </table>
  `;
  show(panel);
}

function switchTab(tab) {
  currentTab = tab;
  document.querySelectorAll('.tab').forEach((button) => {
    button.classList.toggle('active', button.dataset.tab === tab);
  });
  document.getElementById('customers-panel').classList.toggle('hidden', tab !== 'customers');
  document.getElementById('families-panel').classList.toggle('hidden', tab !== 'families');
}

async function signOut() {
  localStorage.removeItem(STORAGE_KEY);
  if (supabase) await supabase.auth.signOut();
  otpState = { pinId: null, phone: null };
  show(document.getElementById('login-screen'));
  hide(document.getElementById('dashboard-screen'));
}

function bindEvents() {
  document.getElementById('setup-form')?.addEventListener('submit', saveSetup);
  document.getElementById('phone-form')?.addEventListener('submit', sendOtp);
  document.getElementById('otp-form')?.addEventListener('submit', verifyOtp);
  document.getElementById('refresh-btn')?.addEventListener('click', refreshAll);
  document.getElementById('sign-out-btn')?.addEventListener('click', signOut);

  document.querySelectorAll('.tab').forEach((button) => {
    button.addEventListener('click', () => switchTab(button.dataset.tab));
  });
}

function boot() {
  loadSavedConfig();
  bindEvents();
  initSupabase();
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', boot);
} else {
  boot();
}