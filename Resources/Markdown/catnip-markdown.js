/* Catnip Engine - xử lý Markdown kiểu GitHub (GPL-3.0-or-later).
 * Dùng markdown-it + footnote + emoji, highlight.js, DOMPurify (xem THIRD_PARTY_NOTICES.md). */
(function () {
  "use strict";

  var root = document.getElementById("md");
  var source = String(window.CATNIP_SOURCE || "");

  function showPlain(note) {
    root.textContent = "";
    if (note) {
      var p = document.createElement("p");
      p.textContent = note;
      root.appendChild(p);
    }
    var pre = document.createElement("pre");
    pre.textContent = source;
    root.appendChild(pre);
  }

  if (!window.markdownit || !window.DOMPurify) {
    showPlain("Không tải được bộ hiển thị Markdown, đang hiện văn bản gốc.");
    return;
  }

  // GitHub: chỉ lấy chữ, số, gạch dưới, gạch nối; khoảng trắng thành gạch nối; trùng thì thêm -1, -2...
  function makeSlugger() {
    var seen = Object.create(null);
    return function (text) {
      var base = text.trim().toLowerCase()
        .replace(/[^\p{L}\p{M}\p{N}\p{Pc} \-]/gu, "")
        .replace(/ /g, "-");
      var slug = base, n = seen[base] || 0;
      if (n > 0) slug = base + "-" + n;
      seen[base] = n + 1;
      return slug;
    };
  }

  try {
    var hljs = window.hljs;
    var md = window.markdownit({
      html: true,
      linkify: true,
      typographer: false,
      breaks: false,
      highlight: function (code, lang) {
        if (lang && hljs && hljs.getLanguage(lang)) {
          try {
            var out = hljs.highlight(code, { language: lang, ignoreIllegals: true }).value;
            return '<pre><code class="hljs language-' + md.utils.escapeHtml(lang) + '">' + out + "</code></pre>";
          } catch (e) { /* rơi xuống không tô màu */ }
        }
        return "";
      }
    });
    if (window.markdownitFootnote) md.use(window.markdownitFootnote);
    if (window.markdownitEmoji) md.use(window.markdownitEmoji);

    // markdown-it căn cột bảng bằng style="text-align:..."; style bị chặn nên đổi sang align="..." như GitHub.
    var rendered = md.render(source).replace(/ style="text-align:(left|center|right)"/g, ' align="$1"');

    var html = window.DOMPurify.sanitize(rendered, {
      FORBID_TAGS: ["style", "form", "button", "textarea", "select", "option", "iframe", "object", "embed"],
      FORBID_ATTR: ["style"],
      ADD_ATTR: ["target"]
    });
    root.innerHTML = html;

    // Tiêu đề: thêm id để link #muc-luc hoạt động.
    var slug = makeSlugger();
    root.querySelectorAll("h1,h2,h3,h4,h5,h6").forEach(function (h) {
      if (!h.id) h.id = slug(h.textContent || "");
    });

    // Danh sách việc cần làm: "- [ ] việc" / "- [x] xong".
    root.querySelectorAll("li").forEach(function (li) {
      var holder = li.firstElementChild && li.firstElementChild.tagName === "P" ? li.firstElementChild : li;
      var node = holder.firstChild;
      if (!node || node.nodeType !== 3) return;
      var m = /^\s*\[([ xX])\](?:\s+|$)/.exec(node.nodeValue);
      if (!m) return;
      node.nodeValue = node.nodeValue.slice(m[0].length);
      var box = document.createElement("input");
      box.type = "checkbox";
      box.disabled = true;
      box.checked = m[1] !== " ";
      box.className = "task-list-item-checkbox";
      holder.insertBefore(box, holder.firstChild);
      li.classList.add("task-list-item");
      if (li.parentElement) li.parentElement.classList.add("contains-task-list");
    });

    // Hộp cảnh báo: > [!NOTE] ... (NOTE, TIP, IMPORTANT, WARNING, CAUTION)
    var titles = { NOTE: "Note", TIP: "Tip", IMPORTANT: "Important", WARNING: "Warning", CAUTION: "Caution" };
    root.querySelectorAll("blockquote").forEach(function (bq) {
      var first = bq.firstElementChild;
      if (!first || first.tagName !== "P" || !first.firstChild || first.firstChild.nodeType !== 3) return;
      var m = /^\s*\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\][ \t]*\n?/i.exec(first.firstChild.nodeValue);
      if (!m) return;
      var type = m[1].toUpperCase();
      first.firstChild.nodeValue = first.firstChild.nodeValue.slice(m[0].length);
      if (first.firstChild.nodeValue === "" && first.firstChild.nextSibling &&
          first.firstChild.nextSibling.nodeName === "BR") {
        first.removeChild(first.firstChild.nextSibling);
      }
      var box = document.createElement("div");
      box.className = "markdown-alert markdown-alert-" + type.toLowerCase();
      var title = document.createElement("p");
      title.className = "markdown-alert-title";
      title.textContent = titles[type];
      box.appendChild(title);
      while (bq.firstChild) box.appendChild(bq.firstChild);
      if (!first.textContent.trim() && !first.querySelector("*")) first.remove();
      bq.parentNode.replaceChild(box, bq);
    });

    // Link ra ngoài mở an toàn.
    root.querySelectorAll("a[href]").forEach(function (a) {
      var href = a.getAttribute("href") || "";
      if (/^https?:/i.test(href)) a.setAttribute("rel", "noopener noreferrer");
    });

    function scrollToAnchor(raw) {
      if (!raw) return false;
      var id = raw;
      try { id = decodeURIComponent(raw); } catch (e) { /* giữ nguyên */ }
      var el = document.getElementById(id) || document.getElementById("user-content-" + id);
      if (!el) return false;
      el.scrollIntoView();
      return true;
    }

    // Link #muc-luc / chú thích cuối trang: tự cuộn, không để WebView điều hướng.
    document.addEventListener("click", function (ev) {
      var a = ev.target && ev.target.closest ? ev.target.closest("a[href]") : null;
      if (!a) return;
      var href = a.getAttribute("href") || "";
      if (href.charAt(0) !== "#") return;
      ev.preventDefault();
      scrollToAnchor(href.slice(1));
    });

    if (window.CATNIP_ANCHOR) scrollToAnchor(window.CATNIP_ANCHOR);
  } catch (err) {
    showPlain("Lỗi khi hiển thị Markdown (" + (err && err.message ? err.message : err) + "). Đang hiện văn bản gốc.");
  }
})();
