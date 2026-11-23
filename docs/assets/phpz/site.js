(() => {
    const root = document.documentElement;
    let theme;
    try { theme = localStorage.getItem('phpz-theme'); } catch (_) {}
    if (theme !== 'light' && theme !== 'dark') {
        theme = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
    }
    root.dataset.theme = theme;

    document.addEventListener('DOMContentLoaded', () => {
        setupSearch();
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

        const button = document.querySelector('.theme-toggle');
        const update = () => {
            root.dataset.theme = theme;
            button.setAttribute('aria-checked', String(theme === 'dark'));
            button.setAttribute('aria-label', theme === 'dark' ? button.dataset.lightLabel : button.dataset.darkLabel);
        };
        button.hidden = false;
        update();
        button.addEventListener('click', () => {
            theme = theme === 'dark' ? 'light' : 'dark';
            try { localStorage.setItem('phpz-theme', theme); } catch (_) {}
            update();
        });
    });

    function setupSearch() {
        const trigger = document.querySelector('.search-open');
        const dialog = document.querySelector('#docs-search');
        const input = dialog.querySelector('input');
        const results = document.querySelector('#search-results');
        const chapterLinks = [...document.querySelectorAll('#chapters a[href], .home-primary, .home-guides a')];
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

        input.addEventListener('input', event => {
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
        });

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
