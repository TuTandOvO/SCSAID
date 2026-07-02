(function () {
    'use strict';

    function initSiteSearch() {
        var form = document.querySelector('.site-search');
        if (!form) return;

        var input = form.querySelector('.site-search__input');
        var panel = form.querySelector('.site-search__panel');
        var list = form.querySelector('.site-search__results');
        var status = form.querySelector('.site-search__status');
        var results = [];
        var activeIndex = -1;
        var debounceTimer = null;
        var requestController = null;

        function setOpen(open) {
            panel.hidden = !open;
            input.setAttribute('aria-expanded', String(open));
            if (!open) {
                activeIndex = -1;
                input.removeAttribute('aria-activedescendant');
            }
        }

        function closeSearch() {
            setOpen(false);
        }

        function openSearch() {
            setOpen(true);
            document.dispatchEvent(new CustomEvent('site-search-open'));
        }

        function setActive(index) {
            var items = list.querySelectorAll('.site-search__result');
            if (!items.length) return;
            if (index < 0) index = items.length - 1;
            if (index >= items.length) index = 0;
            activeIndex = index;
            Array.prototype.forEach.call(items, function (item, itemIndex) {
                item.classList.toggle('site-search__result--active', itemIndex === activeIndex);
                item.setAttribute('aria-selected', String(itemIndex === activeIndex));
            });
            input.setAttribute('aria-activedescendant', items[activeIndex].id);
            items[activeIndex].scrollIntoView({ block: 'nearest' });
        }

        function render(items, query) {
            results = items;
            activeIndex = -1;
            list.textContent = '';
            status.classList.remove('is-loading');

            if (!items.length) {
                status.textContent = 'No matching function or dataset found.';
                openSearch();
                return;
            }

            status.textContent = query ? items.length + (items.length === 1 ? ' result' : ' results') : 'Suggested functions';
            items.forEach(function (item, index) {
                var option = document.createElement('li');
                option.className = 'site-search__result';
                option.id = 'site-search-option-' + index;
                option.setAttribute('role', 'option');
                option.setAttribute('aria-selected', 'false');

                var link = document.createElement('a');
                link.className = 'site-search__result-link';
                link.href = item.url;

                var title = document.createElement('span');
                title.className = 'site-search__result-title';
                title.textContent = item.title;

                var category = document.createElement('span');
                category.className = 'site-search__result-category';
                category.textContent = item.category;

                var description = document.createElement('span');
                description.className = 'site-search__result-description';
                description.textContent = item.description;

                link.appendChild(title);
                link.appendChild(category);
                link.appendChild(description);
                option.appendChild(link);
                option.addEventListener('mouseenter', function () { setActive(index); });
                list.appendChild(option);
            });
            openSearch();
        }

        function performSearch(query, navigateWhenReady) {
            if (requestController) requestController.abort();
            requestController = new AbortController();
            status.textContent = '';
            status.classList.add('is-loading');
            list.textContent = '';
            openSearch();

            var url = new URL(form.action, window.location.href);
            url.searchParams.set('q', query);
            fetch(url.toString(), {
                headers: { 'Accept': 'application/json' },
                signal: requestController.signal
            })
                .then(function (response) {
                    if (!response.ok) throw new Error('Search request failed');
                    return response.json();
                })
                .then(function (items) {
                    render(Array.isArray(items) ? items : [], query);
                    if (navigateWhenReady && items.length) window.location.assign(items[0].url);
                })
                .catch(function (error) {
                    if (error.name === 'AbortError') return;
                    results = [];
                    list.textContent = '';
                    status.classList.remove('is-loading');
                    status.textContent = 'Search is temporarily unavailable. Please try again.';
                    openSearch();
                });
        }

        input.addEventListener('focus', function () {
            if (!results.length) performSearch(input.value.trim(), false);
            else openSearch();
        });

        input.addEventListener('input', function () {
            results = [];
            activeIndex = -1;
            window.clearTimeout(debounceTimer);
            debounceTimer = window.setTimeout(function () {
                performSearch(input.value.trim(), false);
            }, 160);
        });

        input.addEventListener('keydown', function (event) {
            if (event.key === 'ArrowDown') {
                event.preventDefault();
                if (panel.hidden) openSearch();
                setActive(activeIndex + 1);
            } else if (event.key === 'ArrowUp') {
                event.preventDefault();
                if (panel.hidden) openSearch();
                setActive(activeIndex - 1);
            } else if (event.key === 'Enter') {
                event.preventDefault();
                var target = results[activeIndex >= 0 ? activeIndex : 0];
                if (target) window.location.assign(target.url);
                else performSearch(input.value.trim(), true);
            } else if (event.key === 'Escape' && !panel.hidden) {
                event.preventDefault();
                closeSearch();
            }
        });

        form.addEventListener('submit', function (event) {
            event.preventDefault();
            var target = results[activeIndex >= 0 ? activeIndex : 0];
            if (target) window.location.assign(target.url);
            else performSearch(input.value.trim(), true);
        });

        document.addEventListener('click', function (event) {
            if (!form.contains(event.target)) closeSearch();
        });
        document.addEventListener('site-search-close', closeSearch);

        return { close: closeSearch };
    }

    function initDropdownMenus() {
        var items = Array.prototype.slice.call(document.querySelectorAll('.main-nav__item'));
        if (!items.length) return;
        var mobileQuery = window.matchMedia('(max-width: 1179px)');

        function toggleFor(item) {
            return item.querySelector('.main-nav__menu-toggle');
        }

        function closeItem(item) {
            var toggle = toggleFor(item);
            item.classList.remove('main-nav__item--open');
            if (toggle) toggle.setAttribute('aria-expanded', 'false');
        }

        function closeAll(except) {
            items.forEach(function (item) {
                if (item !== except) closeItem(item);
            });
        }

        function openItem(item, persistent) {
            var toggle = toggleFor(item);
            closeAll(item);
            if (persistent) item.classList.add('main-nav__item--open');
            if (toggle) toggle.setAttribute('aria-expanded', 'true');
        }

        items.forEach(function (item) {
            var toggle = toggleFor(item);
            var links = item.querySelectorAll('.main-nav__dropdown-link');
            if (!toggle) return;

            toggle.addEventListener('click', function (event) {
                event.stopPropagation();
                var shouldClose = item.classList.contains('main-nav__item--open') &&
                    (mobileQuery.matches || !item.matches(':hover'));
                if (shouldClose) closeItem(item);
                else openItem(item, true);
            });

            item.addEventListener('mouseenter', function () {
                if (!mobileQuery.matches) openItem(item, true);
            });

            item.addEventListener('mouseleave', function () {
                if (!mobileQuery.matches && !item.contains(document.activeElement)) closeItem(item);
            });

            item.addEventListener('focusin', function () {
                if (!mobileQuery.matches) openItem(item, false);
            });

            item.addEventListener('focusout', function () {
                window.setTimeout(function () {
                    if (!item.contains(document.activeElement) && !item.matches(':hover')) closeItem(item);
                }, 0);
            });

            Array.prototype.forEach.call(links, function (link) {
                link.addEventListener('click', function () { closeAll(); });
            });
        });

        document.addEventListener('click', function (event) {
            if (!event.target.closest('.main-nav__item')) closeAll();
        });

        document.addEventListener('keydown', function (event) {
            if (event.key !== 'Escape') return;
            var openItemElement = document.querySelector('.main-nav__item--open');
            if (!openItemElement) return;
            var toggle = toggleFor(openItemElement);
            closeAll();
            if (toggle) toggle.focus();
        });

        document.addEventListener('site-search-open', function () { closeAll(); });

        function handleBreakpointChange() { closeAll(); }
        if (mobileQuery.addEventListener) mobileQuery.addEventListener('change', handleBreakpointChange);
        else mobileQuery.addListener(handleBreakpointChange);
    }

    function initHeader(search) {
        var header = document.querySelector('.site-header');
        var nav = document.getElementById('site-navigation');
        var toggle = document.querySelector('.nav-toggle');
        var closeButton = document.querySelector('.nav-drawer__close');
        var backdrop = document.querySelector('.nav-backdrop');
        if (!header || !nav || !toggle || !closeButton || !backdrop) return;

        var mobileQuery = window.matchMedia('(max-width: 1179px)');
        var previousFocus = null;

        function focusableItems() {
            return Array.prototype.slice.call(nav.querySelectorAll('a[href], button:not([disabled])'))
                .filter(function (item) { return item.offsetParent !== null; });
        }

        function openMenu() {
            if (!mobileQuery.matches) return;
            if (search) search.close();
            previousFocus = document.activeElement;
            document.body.classList.add('nav-open');
            header.classList.add('site-header--menu-open');
            toggle.setAttribute('aria-expanded', 'true');
            toggle.setAttribute('aria-label', 'Close navigation menu');
            closeButton.focus();
        }

        function closeMenu(restoreFocus) {
            document.body.classList.remove('nav-open');
            header.classList.remove('site-header--menu-open');
            toggle.setAttribute('aria-expanded', 'false');
            toggle.setAttribute('aria-label', 'Open navigation menu');
            if (restoreFocus && previousFocus && typeof previousFocus.focus === 'function') previousFocus.focus();
        }

        toggle.addEventListener('click', function () {
            if (header.classList.contains('site-header--menu-open')) closeMenu(true);
            else openMenu();
        });
        closeButton.addEventListener('click', function () { closeMenu(true); });
        backdrop.addEventListener('click', function () { closeMenu(true); });
        nav.addEventListener('click', function (event) {
            if (mobileQuery.matches && event.target.closest('a[href]')) closeMenu(false);
        });
        document.addEventListener('site-search-open', function () { closeMenu(false); });
        document.addEventListener('keydown', function (event) {
            if (!header.classList.contains('site-header--menu-open')) return;
            if (event.key === 'Escape') {
                event.preventDefault();
                closeMenu(true);
                return;
            }
            if (event.key !== 'Tab') return;
            var items = focusableItems();
            if (!items.length) return;
            var first = items[0];
            var last = items[items.length - 1];
            if (event.shiftKey && document.activeElement === first) {
                event.preventDefault();
                last.focus();
            } else if (!event.shiftKey && document.activeElement === last) {
                event.preventDefault();
                first.focus();
            }
        });

        function handleBreakpointChange() {
            if (!mobileQuery.matches) closeMenu(false);
        }
        if (mobileQuery.addEventListener) mobileQuery.addEventListener('change', handleBreakpointChange);
        else mobileQuery.addListener(handleBreakpointChange);
    }

    function init() {
        var search = initSiteSearch();
        initDropdownMenus();
        initHeader(search);
    }

    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
    else init();
})();
