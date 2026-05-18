// ============================================
// Minimalist Blog - Main Script
// ============================================

document.addEventListener('DOMContentLoaded', function () {

  // --- Common: Current Year ---
  const yearSpan = document.getElementById('current-year');
  if (yearSpan) yearSpan.textContent = new Date().getFullYear();

  // --- Page Detection ---
  const isIndex = document.getElementById('article-list') !== null;
  const isArticle = document.getElementById('article-container') !== null;

  // ========================================
  // HOME PAGE
  // ========================================
  if (isIndex) {
    fetch('data/articles.json')
      .then(res => res.json())
      .then(articles => {
        renderArticleList(articles);
        setupTagFilter(articles);
      })
      .catch(err => {
        document.getElementById('article-list').innerHTML =
          '<p style="color:var(--text-muted)">文章加载失败，请刷新重试。</p>';
      });
  }

  function renderArticleList(articles) {
    const list = document.getElementById('article-list');
    const tagsSet = new Set();

    articles.forEach(a => a.tags.forEach(t => tagsSet.add(t)));

    list.innerHTML = articles.map(a => {
      const tagsHtml = a.tags.map(t =>
        `<a href="#" class="article-tag" data-tag="${t}">${t}</a>`
      ).join('');
      return `
        <article class="article-card" data-tags="${a.tags.join(',')}">
          <div class="article-meta">
            <time class="article-date">${formatDate(a.date)}</time>
            <div class="article-tags">${tagsHtml}</div>
          </div>
          <h2 class="article-title">
            <a href="article.html?id=${a.id}">${a.title}</a>
          </h2>
          <p class="article-excerpt">${a.excerpt}</p>
        </article>
      `;
    }).join('');
  }

  function setupTagFilter(articles) {
    const tagBtns = document.querySelectorAll('.tag-btn');
    const noArticles = document.getElementById('no-articles');

    if (tagBtns.length === 0) return;

    // Show tag buttons for all tags
    tagBtns.forEach(btn => {
      // Add click event to existing tag buttons
    });

    // Handle clicks on both filter buttons and article tag links
    document.addEventListener('click', function (e) {
      const tagBtn = e.target.closest('.tag-btn');
      const articleTag = e.target.closest('.article-tag');

      let tag = null;
      if (tagBtn) {
        tag = tagBtn.dataset.tag;
        // Update active state for tag-btn
        tagBtns.forEach(b => b.classList.remove('active'));
        tagBtn.classList.add('active');
      } else if (articleTag) {
        tag = articleTag.dataset.tag;
        // Update active state for tag-btn
        tagBtns.forEach(b => {
          b.classList.remove('active');
          if (b.dataset.tag === tag) b.classList.add('active');
        });
      }

      if (!tag) return;
      e.preventDefault();

      const cards = document.querySelectorAll('.article-card');
      let visibleCount = 0;

      cards.forEach(card => {
        const tags = card.dataset.tags.split(',');
        if (tag === 'all' || tags.includes(tag)) {
          card.classList.remove('hidden');
          visibleCount++;
        } else {
          card.classList.add('hidden');
        }
      });

      if (noArticles) {
        noArticles.classList.toggle('visible', visibleCount === 0);
      }
    });
  }

  // ========================================
  // ARTICLE DETAIL PAGE
  // ========================================
  if (isArticle) {
    const params = new URLSearchParams(window.location.search);
    const id = params.get('id');

    if (!id) {
      document.getElementById('article-content').innerHTML =
        '<p>未指定文章 ID。</p>';
      return;
    }

    fetch('data/articles.json')
      .then(res => res.json())
      .then(allArticles => {
        const article = allArticles.find(a => a.id === id);
        if (!article) {
          document.getElementById('article-content').innerHTML =
            '<p>文章未找到。</p>';
          return;
        }

        // Update page title and meta
        document.title = article.title + ' · 我的博客';
        document.querySelector('meta[name="description"]').content = article.excerpt;

        // Render header
        document.getElementById('article-title').textContent = article.title;
        document.getElementById('article-date').textContent = formatDate(article.date);
        document.getElementById('article-tags').innerHTML =
          article.tags.map(t => `<span class="article-tag">${t}</span>`).join('');

        // Load and render markdown
        fetch('articles/' + id + '.md')
          .then(res => {
            if (!res.ok) throw new Error('Not found');
            return res.text();
          })
          .then(md => {
            document.getElementById('article-content').innerHTML = renderMarkdown(md);
          })
          .catch(() => {
            document.getElementById('article-content').innerHTML =
              '<p>文章内容加载失败。</p>';
          });

        // Previous / Next navigation
        const idx = allArticles.indexOf(article);
        const prev = idx > 0 ? allArticles[idx - 1] : null;
        const next = idx < allArticles.length - 1 ? allArticles[idx + 1] : null;

        const nav = document.getElementById('article-nav');
        nav.innerHTML = (
          (prev ? `<div class="article-nav-link prev"><div class="article-nav-label">上一篇</div><a href="article.html?id=${prev.id}" class="article-nav-title">← ${prev.title}</a></div>` : '<div></div>') +
          (next ? `<div class="article-nav-link next"><div class="article-nav-label">下一篇</div><a href="article.html?id=${next.id}" class="article-nav-title">${next.title} →</a></div>` : '<div></div>')
        );
      })
      .catch(() => {
        document.getElementById('article-content').innerHTML =
          '<p>文章数据加载失败。</p>';
      });
  }

  // ========================================
  // HELPERS
  // ========================================
  function formatDate(dateStr) {
    const d = new Date(dateStr);
    return d.getFullYear() + ' 年 ' + (d.getMonth() + 1) + ' 月 ' + d.getDate() + ' 日';
  }

});
