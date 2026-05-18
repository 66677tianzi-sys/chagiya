// ============================================
// Minimal Markdown Parser
// ============================================

function renderMarkdown(md) {
  let html = '';
  const lines = md.split('\n');
  let i = 0;
  let inCodeBlock = false;
  let codeBuffer = [];

  while (i < lines.length) {
    let line = lines[i];

    // Code block
    if (line.trim().startsWith('```')) {
      if (inCodeBlock) {
        html += '<pre><code>' + codeBuffer.join('\n') + '</code></pre>\n';
        codeBuffer = [];
        inCodeBlock = false;
        i++;
        continue;
      } else {
        inCodeBlock = true;
        i++;
        continue;
      }
    }

    if (inCodeBlock) {
      codeBuffer.push(escapeHtml(line));
      i++;
      continue;
    }

    // Empty line
    if (line.trim() === '') {
      i++;
      continue;
    }

    // Headings
    if (line.startsWith('### ')) {
      html += '<h3>' + parseInline(line.slice(4)) + '</h3>\n';
      i++;
      continue;
    }
    if (line.startsWith('## ')) {
      html += '<h2>' + parseInline(line.slice(3)) + '</h2>\n';
      i++;
      continue;
    }
    if (line.startsWith('# ')) {
      html += '<h1>' + parseInline(line.slice(2)) + '</h1>\n';
      i++;
      continue;
    }

    // Blockquote
    if (line.startsWith('> ')) {
      let quoteLines = [];
      while (i < lines.length && lines[i].startsWith('> ')) {
        quoteLines.push(parseInline(lines[i].slice(2)));
        i++;
      }
      html += '<blockquote>' + quoteLines.join('<br>') + '</blockquote>\n';
      continue;
    }

    // Unordered list
    if (line.match(/^[\-*]\s/)) {
      let listItems = [];
      while (i < lines.length && lines[i].match(/^[\-*]\s/)) {
        listItems.push('<li>' + parseInline(lines[i].replace(/^[\-*]\s/, '')) + '</li>');
        i++;
      }
      html += '<ul>' + listItems.join('') + '</ul>\n';
      continue;
    }

    // Ordered list
    if (line.match(/^\d+\.\s/)) {
      let listItems = [];
      while (i < lines.length && lines[i].match(/^\d+\.\s/)) {
        listItems.push('<li>' + parseInline(lines[i].replace(/^\d+\.\s/, '')) + '</li>');
        i++;
      }
      html += '<ol>' + listItems.join('') + '</ol>\n';
      continue;
    }

    // Paragraph (collect until next empty line or block element)
    let paraLines = [];
    while (i < lines.length && lines[i].trim() !== '' &&
           !lines[i].startsWith('#') && !lines[i].startsWith('> ') &&
           !lines[i].match(/^[\-*]\s/) && !lines[i].match(/^\d+\.\s/) &&
           !lines[i].trim().startsWith('```')) {
      paraLines.push(parseInline(lines[i]));
      i++;
    }
    html += '<p>' + paraLines.join('<br>') + '</p>\n';
  }

  return html;
}

function parseInline(text) {
  return escapeHtml(text)
    .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
    .replace(/\*(.+?)\*/g, '<em>$1</em>')
    .replace(/`(.+?)`/g, '<code>$1</code>')
    .replace(/\[(.+?)\]\((.+?)\)/g, '<a href="$2">$1</a>');
}

function escapeHtml(text) {
  const map = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' };
  return text.replace(/[&<>"]/g, c => map[c]);
}
