// Incus Scripts - Docs site JS
// Search and filter logic

const TOAST = () => {
  const t = document.createElement('div');
  t.className = 'toast';
  t.textContent = 'Copied!';
  document.body.appendChild(t);
  setTimeout(() => t.classList.add('show'), 10);
  setTimeout(() => { t.classList.remove('show'); setTimeout(() => t.remove(), 250); }, 1500);
};

// Global click handler for copy buttons
document.addEventListener('click', (e) => {
  if (e.target.classList.contains('copy-btn')) {
    const target = e.target.getAttribute('data-copy');
    if (target) {
      const decoded = target.replace(/\\n/g, '\n').replace(/\\t/g, '\t').replace(/\\"/g, '"');
      navigator.clipboard.writeText(decoded).then(TOAST);
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

  // Keyboard shortcut: '/' focuses search
  document.addEventListener('keydown', (e) => {
    if (e.key === '/' && search && document.activeElement !== search) {
      e.preventDefault();
      search.focus();
    }
  });
}
