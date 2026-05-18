// ============================================
// Minimalist Blog - Main Script
// ============================================

document.addEventListener('DOMContentLoaded', function () {

  // --- Tag Filtering (Home Page) ---
  const tagBtns = document.querySelectorAll('.tag-btn');
  const articles = document.querySelectorAll('.article-card');
  const noArticles = document.getElementById('no-articles');

  if (tagBtns.length > 0) {
    tagBtns.forEach(btn => {
      btn.addEventListener('click', function () {
        tagBtns.forEach(b => b.classList.remove('active'));
        this.classList.add('active');

        const tag = this.dataset.tag;
        let visibleCount = 0;

        articles.forEach(article => {
          const articleTags = article.dataset.tags || '';
          const tags = articleTags.split(',').map(t => t.trim());

          if (tag === 'all' || tags.includes(tag)) {
            article.classList.remove('hidden');
            visibleCount++;
          } else {
            article.classList.add('hidden');
          }
        });

        if (noArticles) {
          noArticles.classList.toggle('visible', visibleCount === 0);
        }
      });
    });
  }

  // --- Current year in footer ---
  const yearSpan = document.getElementById('current-year');
  if (yearSpan) {
    yearSpan.textContent = new Date().getFullYear();
  }

  // --- Mobile menu toggle (if needed in future) ---

});
