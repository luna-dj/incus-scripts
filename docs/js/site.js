// Incus Scripts - Docs site JS
// Search, filter logic, copy buttons, and provider switching

const TOAST = () => {
  const t = document.createElement('div');
  t.className = 'toast';
  t.textContent = 'Copied!';
  document.body.appendChild(t);
  setTimeout(() => t.classList.add('show'), 10);
  setTimeout(() => { t.classList.remove('show'); setTimeout(() => t.remove(), 250); }, 1500);
};

// Provider switching: Codeberg (default) or GitHub
const CODEBERG_BASE = 'https://codeberg.org/luna-dj/incus-scripts/raw/branch/main';
const GITHUB_BASE = 'https://raw.githubusercontent.com/luna-dj/incus-scripts/main';

const getProvider = () => localStorage.getItem('provider') || 'codeberg';
const setProvider = (p) => { localStorage.setItem('provider', p); };

// Convert a URL between providers
const switchProvider = (url, to) => {
  if (to === 'github') return url.replace(CODEBERG_BASE, GITHUB_BASE);
  return url.replace(GITHUB_BASE, CODEBERG_BASE);
};

// Update all install commands on the page
const updateInstallCommands = (provider) => {
  // Update data-copy attributes on copy buttons
  document.querySelectorAll('.copy-btn[data-copy]').forEach(btn => {
    const orig = btn.getAttribute('data-orig-copy');
    const current = btn.getAttribute('data-copy');
    if (!orig && current) btn.setAttribute('data-orig-copy', current);
    if (orig) btn.setAttribute('data-copy', switchProvider(orig, provider));
  });
  // Update visible pre/code blocks
  document.querySelectorAll('.code-block pre code').forEach(code => {
    const orig = code.getAttribute('data-orig-text');
    const current = code.textContent;
    if (!orig && current) code.setAttribute('data-orig-text', current);
    if (orig) code.textContent = switchProvider(orig, provider);
  });
  // Update provider badge/label if present
  const badge = document.getElementById('provider-label');
  if (badge) badge.textContent = provider === 'github' ? 'GitHub' : 'Codeberg';
};

// Init provider selector
const initProvider = () => {
  const sel = document.getElementById('provider-select');
  if (!sel) return;
  const current = getProvider();
  sel.value = current;
  updateInstallCommands(current);
  sel.addEventListener('change', (e) => {
    setProvider(e.target.value);
    updateInstallCommands(e.target.value);
  });
};

// Global click handler for copy buttons
document.addEventListener('click', (e) => {
  if (e.target.classList.contains('copy-btn')) {
    const target = e.target.getAttribute('data-copy');
    if (target) {
      navigator.clipboard.writeText(target).then(TOAST);
      e.target.classList.add('copied');
      const old = e.target.textContent;
      e.target.textContent = 'Copied';
      setTimeout(() => { e.target.textContent = old; e.target.classList.remove('copied'); }, 1500);
    }
  }
});

// Index page logic
if (document.querySelector('.app-grid')) {
  const search = document.getElementById('search');
  const filterBtns = document.querySelectorAll('.filter-btn');
  const cards = document.querySelectorAll('.app-card');
  const empty = document.querySelector('.app-empty');
  const totalCount = document.getElementById('total-count');
  const visibleCount = document.getElementById('visible-count');

  let activeCategory = 'all';

  const apply = () => {
    const q = (search?.value || '').toLowerCase().trim();
    let visible = 0;
    cards.forEach(card => {
      const name = (card.dataset.name || '').toLowerCase();
      const desc = (card.dataset.desc || '').toLowerCase();
      const cat = card.dataset.category || 'other';
      const matchesSearch = !q || name.includes(q) || desc.includes(q);
      const matchesCategory = activeCategory === 'all' || cat === activeCategory;
      const show = matchesSearch && matchesCategory;
      card.style.display = show ? '' : 'none';
      if (show) visible++;
    });
    if (visibleCount) visibleCount.textContent = visible;
    if (empty) empty.style.display = visible === 0 ? 'block' : 'none';
  };

  if (search) search.addEventListener('input', apply);
  filterBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      filterBtns.forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      activeCategory = btn.dataset.category;
      apply();
    });
  });
  document.addEventListener('keydown', (e) => {
    if (e.key === '/' && search && document.activeElement !== search) {
      e.preventDefault();
      search.focus();
    }
  });
}

// Init provider on load
document.addEventListener('DOMContentLoaded', initProvider);
