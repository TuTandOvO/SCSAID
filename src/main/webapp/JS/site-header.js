(function () {
    'use strict';

    function initHeader() {
        var header = document.querySelector('.site-header');
        var nav = document.getElementById('site-navigation');
        var toggle = document.querySelector('.nav-toggle');
        var closeButton = document.querySelector('.nav-drawer__close');
        var backdrop = document.querySelector('.nav-backdrop');
        if (!header || !nav || !toggle || !closeButton || !backdrop) return;

        var mobileQuery = window.matchMedia('(max-width: 1023px)');
        var previousFocus = null;

        function focusableItems() {
            return Array.prototype.slice.call(nav.querySelectorAll('a[href], button:not([disabled])'))
                .filter(function (item) { return item.offsetParent !== null; });
        }

        function openMenu() {
            if (!mobileQuery.matches) return;
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
            if (restoreFocus && previousFocus && typeof previousFocus.focus === 'function') {
                previousFocus.focus();
            }
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

    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', initHeader);
    else initHeader();
})();
