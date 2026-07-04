/**
 * ==========================================================================
 * Newsletter / mailing-list signup modal — scSAID
 *
 * Opens from the "About" menu (button with [data-newsletter-open]). The form
 * POSTs to Buttondown's embed-subscribe endpoint through a hidden iframe, so
 * the visitor never leaves scSAID and sees our own styled confirmation state
 * instead of the raw Buttondown page.
 *
 * Markup lives in includes/header.jsp (#newsletterModal), present on every
 * page because the header include is.
 * ==========================================================================
 */
(function () {
    'use strict';

    var overlay, dialog, form, formView, successView, lastFocus;

    function focusable() {
        if (!dialog) return [];
        return Array.prototype.slice.call(
            dialog.querySelectorAll('a[href], button:not([disabled]), input:not([disabled]), [tabindex]:not([tabindex="-1"])')
        ).filter(function (el) { return el.offsetParent !== null; });
    }

    function open() {
        if (!overlay) return;
        lastFocus = document.activeElement;
        overlay.hidden = false;
        overlay.classList.remove('is-closing');
        document.body.style.overflow = 'hidden';
        // Always land on the form view when re-opened.
        if (formView && successView) {
            formView.hidden = false;
            successView.hidden = true;
        }
        var email = overlay.querySelector('#nl-email');
        if (email) { try { email.focus(); } catch (e) {} }
        document.addEventListener('keydown', onKeydown, true);
    }

    function close() {
        if (!overlay || overlay.hidden) return;
        overlay.classList.add('is-closing');
        document.removeEventListener('keydown', onKeydown, true);
        window.setTimeout(function () {
            overlay.hidden = true;
            overlay.classList.remove('is-closing');
            document.body.style.overflow = '';
        }, 180);
        if (lastFocus && typeof lastFocus.focus === 'function') {
            try { lastFocus.focus(); } catch (e) {}
        }
    }

    function onKeydown(event) {
        if (event.key === 'Escape') {
            event.preventDefault();
            close();
            return;
        }
        if (event.key === 'Tab') {
            var items = focusable();
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
        }
    }

    function onSubmit() {
        // The form target is the hidden iframe, so the browser posts to
        // Buttondown without navigating. We optimistically show the success
        // state; Buttondown emails a confirmation link to complete opt-in.
        var email = form.querySelector('#nl-email');
        if (email && !email.value) { return; }
        window.setTimeout(function () {
            if (formView && successView) {
                formView.hidden = true;
                successView.hidden = false;
                var done = successView.querySelector('[data-newsletter-done]');
                if (done) { try { done.focus(); } catch (e) {} }
            }
        }, 150);
        // allow native submit into the iframe to proceed
        return true;
    }

    function init() {
        overlay = document.getElementById('newsletterModal');
        if (!overlay) return;
        dialog = overlay.querySelector('.nl-modal');
        form = overlay.querySelector('#newsletterForm');
        formView = overlay.querySelector('[data-newsletter-formview]');
        successView = overlay.querySelector('[data-newsletter-success]');

        // Openers: any element with [data-newsletter-open].
        document.addEventListener('click', function (event) {
            var opener = event.target.closest('[data-newsletter-open]');
            if (opener) {
                event.preventDefault();
                open();
            }
        });

        // Closers inside the modal.
        overlay.addEventListener('click', function (event) {
            if (event.target === overlay || event.target.closest('[data-newsletter-close]')) {
                event.preventDefault();
                close();
            }
        });

        if (form) {
            form.addEventListener('submit', onSubmit);
        }
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
})();
