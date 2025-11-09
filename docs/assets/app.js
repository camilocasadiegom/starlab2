const GITHUB_USER = "camilocasadiegom";
const GITHUB_REPO = "starlab2";
const BACKEND_URL  = "https://TU_URL_CF";  // p.ej. https://xxxxx.trycloudflare.com

document.getElementById('repoLink').href = `https://github.com/${GITHUB_USER}/${GITHUB_REPO}`;

const btnOpen = document.getElementById('openBackend');
btnOpen.href = BACKEND_URL || '#';

async function checkHealth() {
  const el = document.getElementById('backendStatus');
  try {
    const r = await fetch(`${BACKEND_URL}/health`, {cache:'no-store'});
    if (r.ok) {
      el.textContent = 'Online ✅';
      el.style.color = '#7ef4b6';
    } else {
      el.textContent = `Offline ⛔ (${r.status})`;
    }
  } catch(e) {
    el.textContent = 'Offline ⛔';
  }
}
document.getElementById('tryAgain').addEventListener('click', checkHealth);
checkHealth();

// Selector de mockups/tema
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
