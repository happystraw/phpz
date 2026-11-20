(() => {
    const root = document.documentElement;
    let theme;
    try { theme = localStorage.getItem('phpz-theme'); } catch (_) {}
    if (theme !== 'light' && theme !== 'dark') {
        theme = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
    }
    root.dataset.theme = theme;

    document.addEventListener('DOMContentLoaded', () => {
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
})();
