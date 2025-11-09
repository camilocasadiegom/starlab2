const GITHUB_USER = "camilocasadiegom";
const GITHUB_REPO = "starlab2";
const BACKEND_URL  = "https://TU_URL_DE_TRYCLOUDFLARE.com";  // p.ej. https://xxxxx.trycloudflare.com

// Enlaces
const repoA = document.getElementById('repoLink');
if (repoA) repoA.href = `https://github.com/${GITHUB_USER}/${GITHUB_REPO}`;

const btnOpen = document.getElementById('openBackend');
const statusEl = document.getElementById('backendStatus');
const retryBtn = document.getElementById('tryAgain');

// Helper seguro: nunca navegar automáticamente
function safeSetBackendLink(url) {
  if (!btnOpen) return;
  if (!url || !/^https?:\/\//i.test(url)) {
    btnOpen.href = "javascript:void(0)";
    btnOpen.classList.add('disabled');
  } else {
    btnOpen.href = url;
    btnOpen.classList.remove('disabled');
  }
}

safeSetBackendLink(BACKEND_URL);

// Health check solo si hay URL válida
async function checkHealth() {
  if (!statusEl) return;
  if (!BACKEND_URL || !/^https?:\/\//i.test(BACKEND_URL)) {
    statusEl.textContent = 'Sin URL configurada';
    statusEl.style.color = '#ffd166'; // ámbar
    return;
  }
  statusEl.textContent = 'Verificando…';
  statusEl.style.color = '';
  try {
    const r = await fetch(`${BACKEND_URL.replace(/\/+$/,'')}/health`, {cache:'no-store', mode:'cors'});
    if (r.ok) {
      statusEl.textContent = 'Online ✅';
      statusEl.style.color = '#7ef4b6';
    } else {
      statusEl.textContent = `Offline ⛔ (${r.status})`;
      statusEl.style.color = '#fca5a5';
    }
  } catch (e) {
    statusEl.textContent = 'Offline ⛔';
    statusEl.style.color = '#fca5a5';
  }
}

if (retryBtn) retryBtn.addEventListener('click', checkHealth);
checkHealth();

// Selector de mockups/tema (sin navegación)
const map = {
  cards: {theme:'theme-cards', el: '#mock-cards'},
  dark:  {theme:'theme-dark',  el: '#mock-dark'},
  steps: {theme:'theme-steps', el: '#mock-steps'},
};
document.querySelectorAll('.segmented .seg').forEach(btn=>{
  btn.addEventListener('click', ()=>{
    document.querySelectorAll('.seg').forEach(b=>b.classList.remove('active'));
    btn.classList.add('active');
    const key = btn.dataset.theme;
    document.body.className = map[key].theme;
    document.querySelectorAll('.mock').forEach(m=>m.classList.remove('visible'));
    document.querySelector(map[key].el).classList.add('visible');
  });
});
