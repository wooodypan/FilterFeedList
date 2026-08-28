/// RSS 推荐订阅页（网页）的配置与注入脚本。
///
/// 推荐链接：一个聚合了热门 RSS 源的 GitHub 仓库。
/// 注入脚本的作用：GitHub 页面渲染完成后，给所有「文本以 http 开头」的 `<a>` 链接
/// 在其右侧追加一个「导入」按钮；用户点「导入」时，把该链接通过 JS 通道
/// `ImportRssChannel` 回传给 Flutter，再由路由跳转到 RSS 编辑页预填地址。
library;

/// 推荐订阅列表地址。
const String kRssRecommendUrl =
    'https://github.com/weekend-project-space/top-rss-list';

/// 页面加载完成后注入的 JavaScript。
///
/// 行为：
/// 1) 遍历所有 `<a>`，若其 `textContent` 以 `http` 开头且 `href` 是 http(s) 链接，
///    则在该 `<a>` 右侧插入一个「导入」按钮；
/// 2) 点「导入」时阻止默认跳转，并通过 `ImportRssChannel.postMessage(href)` 回传链接；
/// 3) GitHub 是动态渲染（SPA/ hydration），用 `MutationObserver` 持续处理后续出现的新链接，
///    并加一次 `setTimeout` 兜底，避免初次 `onPageFinished` 时正文尚未渲染。
const String kRssRecommendInjectScript = r'''
(function () {
  function process() {
    var links = document.querySelectorAll('a');
    for (var i = 0; i < links.length; i++) {
      var a = links[i];
      // 已经处理过的跳过，避免重复插入按钮
      if (a.getAttribute('data-rss-imported') === '1') continue;
      var text = (a.textContent || '').trim();
      var href = a.href || '';
      if (text.toLowerCase().indexOf('http') === 0 && /^https?:\/\//i.test(href)) {
        a.setAttribute('data-rss-imported', '1');
        var btn = document.createElement('button');
        btn.textContent = '导入';
        btn.style.marginLeft = '6px';
        btn.style.cursor = 'pointer';
        btn.style.border = '1px solid #2da44e';
        btn.style.background = '#f0fff4';
        btn.style.color = '#1a7f37';
        btn.style.borderRadius = '4px';
        btn.style.padding = '0 6px';
        btn.addEventListener('click', (function (url) {
          return function (e) {
            e.preventDefault();
            e.stopPropagation();
            if (typeof ImportRssChannel !== 'undefined') {
              ImportRssChannel.postMessage(url);
            }
          };
        })(href));
        if (a.parentNode) {
          a.parentNode.insertBefore(btn, a.nextSibling);
        }
      }
    }
  }
  // 先处理一次（此时可能只有骨架）
  process();
  // 兜底：等一会儿再处理（正文 hydrate 后链接才出现）
  setTimeout(process, 500);
  // 持续监听后续动态渲染出的链接
  if (window.MutationObserver) {
    new MutationObserver(process).observe(document.body, {
      childList: true,
      subtree: true,
    });
  }
})();
''';
