const GITHUB_USER = "camilocasadiegom";
const GITHUB_REPO = "starlab2";

const repoA   = document.getElementById('repoLink');
const statusE = document.getElementById('backendStatus');
const retryB  = document.getElementById('tryAgain');
const btnOpen = document.getElementById('openBackend');
const frame   = document.getElementById('docsFrame');
const hint    = document.getElementById('embedHint');

if (repoA) repoA.href = `https://github.com/${GITHUB_USER}/${GITHUB_REPO}`;

function safeLink(href){
  if (!href || !/^https?:\/\//i.test(href)){ btnOpen.href="javascript:void(0)"; btnOpen.classList.add('disabled'); }
  else { btnOpen.href=href; btnOpen.classList.remove('disabled'); }
}

async function fetchJSON(url){
  const r = await fetch(url, {cache:'no-store'});
  if (!r.ok) throw new Error(r.status);
  return r.json();
}
function timeout(ms){ return new Promise((_,rej)=>setTimeout(()=>rej(new Error('timeout')),ms)); }
async function checkHealth(url){
  const clean = url.replace(/\/+$/,'');
  const controller = new AbortController();
  const p = fetch(`${clean}/health`, {signal:controller.signal, cache:'no-store'}).then(r=>({ok:r.ok, url:clean, status:r.status})).catch(()=>({ok:false,url:clean,status:0}));
  const race = Promise.race([p, timeout(3500)]);
  try { return await race; } finally { controller.abort(); }
}

let activeURL = null;

async function resolveBackend(){
  statusE.textContent = 'Verificando…'; statusE.style.color='';
  let urls = [];
  try{
    const data = await fetchJSON('assets/urls.json');
    urls = Array.isArray(data.tunnels)? data.tunnels.filter(Boolean): [];
  }catch{ /* sin lista */ }

  for (const u of urls){
    const res = await checkHealth(u);
    if (res && res.ok){
      activeURL = res.url;
      statusE.textContent = 'Online ✅';
      statusE.style.color = '#7ef4b6';
      safeLink(activeURL);
      if (frame){
        frame.src = `${activeURL}/docs`;
        frame.style.display = 'block';
        if (hint) hint.style.display = 'none';
      }
      return;
    }
  }
  // Si ninguna funcionó
  activeURL = null;
  statusE.textContent = urls.length ? 'Offline ⛔' : 'Sin URL configurada';
  statusE.style.color = urls.length ? '#fca5a5' : '#ffd166';
  safeLink(null);
  if (frame){ frame.style.display='none'; if (hint) hint.style.display=''; }
}

if (retryB) retryB.addEventListener('click', resolveBackend);
resolveBackend();

// Selector de mockups/tema
const map = {
  cards: {theme:'theme-cards', el:'#mock-cards'},
  dark:  {theme:'theme-dark',  el:'#mock-dark'},
  steps: {theme:'theme-steps', el:'#mock-steps'},
};
document.querySelectorAll('.segmented .seg').forEach(b=>{
  b.addEventListener('click', ()=>{
    document.querySelectorAll('.seg').forEach(x=>x.classList.remove('active'));
    b.classList.add('active');
    const k=b.dataset.theme;
    document.querySelectorAll('.mock').forEach(m=>m.classList.remove('visible'));
    document.querySelector(map[k].el).classList.add('visible');
    document.body.className = map[k].theme;
  });
});
