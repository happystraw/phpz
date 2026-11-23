(() => {
    const root = document.documentElement;
    let theme;
    try { theme = localStorage.getItem('phpz-theme'); } catch (_) {}
    if (theme !== 'light' && theme !== 'dark') theme = 'system';
    const systemTheme = window.matchMedia('(prefers-color-scheme: dark)');
    function applyTheme() {
        root.dataset.theme = theme === 'system' ? (systemTheme.matches ? 'dark' : 'light') : theme;
    }
    applyTheme();
    systemTheme.addEventListener('change', applyTheme);

    document.addEventListener('DOMContentLoaded', () => {
        setupSearch();
        setupCommandCopy();
        setupChapterDrawer();
        const headerMenus = [...document.querySelectorAll('.header-tools details')];
        document.addEventListener('click', event => {
            for (const menu of headerMenus) {
                if (!menu.contains(event.target)) menu.open = false;
            }
        });
        document.addEventListener('keydown', event => {
            const menu = headerMenus.find(item => item.open && item.contains(event.target));
            if (menu && event.key === 'Escape') {
                menu.open = false;
                menu.querySelector('summary').focus();
            }
        });

        const picker = document.querySelector('.theme-picker');
        const options = picker.querySelectorAll('[data-theme-option]');
        const markSelection = () => {
            for (const option of options) {
                option.setAttribute('aria-pressed', String(option.dataset.themeOption === theme));
            }
        };
        markSelection();
        picker.hidden = false;
        for (const option of options) {
            option.addEventListener('click', () => {
                theme = option.dataset.themeOption;
                try { localStorage.setItem('phpz-theme', theme); } catch (_) {}
                applyTheme();
                markSelection();
                picker.open = false;
                picker.querySelector('summary').focus();
            });
        }
    });

    function setupChapterDrawer() {
        const drawer = document.querySelector('#chapter-drawer');
        if (!drawer) return;
        const chapters = document.querySelector('#chapters');
        const details = chapters.parentElement;
        const trigger = details.querySelector('summary');
        const narrow = window.matchMedia('(max-width: 1023px)');
        trigger.setAttribute('aria-haspopup', 'dialog');
        trigger.setAttribute('aria-controls', drawer.id);
        trigger.setAttribute('aria-expanded', 'false');
        trigger.addEventListener('click', event => {
            if (!narrow.matches) return;
            event.preventDefault();
            drawer.append(chapters);
            drawer.showModal();
            trigger.setAttribute('aria-expanded', 'true');
            chapters.querySelector('[aria-current="page"]')?.scrollIntoView({ block: 'nearest' });
        });
        drawer.addEventListener('close', () => {
            details.append(chapters);
            trigger.setAttribute('aria-expanded', 'false');
        });
        drawer.addEventListener('click', event => {
            if (event.target === drawer && event.clientX >= drawer.getBoundingClientRect().right) drawer.close();
        });
        narrow.addEventListener('change', () => { if (drawer.open) drawer.close(); });
    }

    function setupCommandCopy() {
        const button = document.querySelector('.project-copy');
        if (!button) return;
        const code = document.querySelector('.project-command code');
        const status = document.querySelector('.copy-status');
        let timer;
        button.hidden = false;
        button.addEventListener('click', async () => {
            try {
                await navigator.clipboard.writeText(code.textContent);
                button.classList.add('is-copied');
                status.textContent = button.dataset.copied;
            } catch {
                const range = document.createRange();
                range.selectNodeContents(code);
                const selection = window.getSelection();
                selection.removeAllRanges();
                selection.addRange(range);
                button.classList.remove('is-copied');
                status.textContent = button.dataset.manual;
            }
            clearTimeout(timer);
            timer = setTimeout(() => {
                button.classList.remove('is-copied');
                status.textContent = '';
            }, 1500);
        });
    }

    function setupSearch() {
        const trigger = document.querySelector('.search-open');
        const dialog = document.querySelector('#docs-search');
        const input = dialog.querySelector('input');
        const results = document.querySelector('#search-results');
        const chapterLinks = [...document.querySelectorAll('#chapters a[href]')];
        let pagefind;
        let timer;
        let revision = 0;

        function resultLink(url, title, excerpt, section = false) {
            const link = document.createElement('a');
            link.className = 'search-result';
            link.href = url;
            const icon = document.createElement('span');
            icon.className = section ? 'search-result-icon is-section' : 'search-result-icon';
            icon.setAttribute('aria-hidden', 'true');
            const body = document.createElement('span');
            const label = document.createElement('span');
            label.className = 'search-result-title';
            label.textContent = title;
            body.append(label);
            if (excerpt) {
                const snippet = document.createElement('span');
                snippet.className = 'search-result-excerpt';
                const parsed = new DOMParser().parseFromString(excerpt, 'text/html').body;
                for (const node of parsed.childNodes) {
                    if (node.nodeName === 'MARK') {
                        const mark = document.createElement('mark');
                        mark.textContent = node.textContent;
                        snippet.append(mark);
                    } else {
                        snippet.append(node.textContent);
                    }
                }
                body.append(snippet);
            }
            link.append(icon, body);
            return link;
        }

        function showDefaultResults() {
            results.replaceChildren(...chapterLinks.map(link => resultLink(link.href, link.textContent)));
            results.scrollTop = 0;
        }

        function showStatus(message) {
            const status = document.createElement('p');
            status.className = 'search-status';
            status.textContent = message;
            results.replaceChildren(status);
        }

        function loadPagefind() {
            pagefind ??= import('/phpz/pagefind/pagefind.js').then(async index => {
                await index.options({ baseUrl: '/phpz/' });
                return index;
            }).catch(error => {
                pagefind = undefined;
                throw error;
            });
            return pagefind;
        }

        function scheduleSearch(event) {
            clearTimeout(timer);
            const current = ++revision;
            if (event.isComposing) return;
            const query = input.value.trim();
            if (!query) {
                showDefaultResults();
                return;
            }
            showStatus(dialog.dataset.loading);
            timer = setTimeout(async () => {
                try {
                    const index = await loadPagefind();
                    const { results: matches } = await index.search(query);
                    const pages = await Promise.all(matches.map(match => match.data()));
                    if (current !== revision || !dialog.open) return;
                    if (!pages.length) {
                        showStatus(dialog.dataset.empty);
                        return;
                    }
                    results.replaceChildren(...pages.map(page => {
                        const group = document.createElement('section');
                        group.className = 'search-result-group';
                        const heading = document.createElement('h2');
                        heading.textContent = page.meta.title;
                        group.append(heading, ...page.sub_results.map(hit =>
                            resultLink(hit.url, hit.title, hit.excerpt, Boolean(hit.anchor))
                        ));
                        return group;
                    }));
                    results.scrollTop = 0;
                } catch {
                    if (current === revision && dialog.open) showStatus(dialog.dataset.error);
                }
            }, 180);
        }

        input.addEventListener('input', scheduleSearch);
        input.addEventListener('compositionend', scheduleSearch);

        function openSearch() {
            dialog.showModal();
            input.value = '';
            showDefaultResults();
            input.focus();
            loadPagefind().catch(() => {});
        }

        trigger.hidden = false;
        if (/Mac|iPhone|iPad/.test(navigator.platform)) trigger.querySelector('kbd').textContent = '⌘K';
        trigger.addEventListener('click', openSearch);
        dialog.addEventListener('close', () => {
            clearTimeout(timer);
            ++revision;
        });
        dialog.addEventListener('click', event => {
            if (event.target === dialog) {
                const { left, top, right, bottom } = dialog.getBoundingClientRect();
                if (event.clientX < left || event.clientX > right || event.clientY < top || event.clientY > bottom) dialog.close();
            }
            if (event.target.closest('.search-result') && !event.ctrlKey && !event.metaKey && !event.shiftKey && !event.altKey) {
                dialog.close();
            }
        });
        dialog.addEventListener('keydown', event => {
            if (event.isComposing || event.keyCode === 229) return;
            if (event.key === 'Escape') {
                event.preventDefault();
                dialog.close();
                return;
            }
            if (event.target !== input && !event.target.matches('.search-result')) return;
            const links = [...results.querySelectorAll('.search-result')];
            const current = links.indexOf(event.target);
            if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
                event.preventDefault();
                const next = current + (event.key === 'ArrowDown' ? 1 : -1);
                (next < 0 ? input : links[next])?.focus();
            } else if (event.target === input && event.key === 'Enter' && links.length) {
                event.preventDefault();
                links[0].click();
            }
        });
        document.addEventListener('keydown', event => {
            if (!event.repeat && !event.isComposing && (event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 'k') {
                event.preventDefault();
                if (dialog.open) dialog.close();
                else openSearch();
            }
        });
    }
})();
