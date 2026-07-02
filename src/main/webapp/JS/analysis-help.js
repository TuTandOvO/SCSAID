(function () {
    'use strict';

    var activeButton = null;
    var popover = null;

    function ensurePopover() {
        if (popover) return popover;
        popover = document.createElement('div');
        popover.id = 'analysis-help-popover';
        popover.className = 'analysis-help-popover';
        popover.setAttribute('role', 'tooltip');
        popover.hidden = true;
        document.body.appendChild(popover);
        return popover;
    }

    function closeHelp() {
        if (activeButton) {
            activeButton.setAttribute('aria-expanded', 'false');
            activeButton.removeAttribute('aria-controls');
        }
        if (popover) popover.hidden = true;
        activeButton = null;
    }

    function positionPopover(button) {
        var box = popover.getBoundingClientRect();
        var trigger = button.getBoundingClientRect();
        var gutter = 8;
        var viewportPad = 12;
        var left = trigger.left + (trigger.width / 2) - (box.width / 2);
        left = Math.max(viewportPad, Math.min(left, window.innerWidth - box.width - viewportPad));

        var below = trigger.bottom + gutter;
        var above = trigger.top - box.height - gutter;
        var top = below;
        if (below + box.height > window.innerHeight - viewportPad && above >= viewportPad) {
            top = above;
        }

        popover.style.left = Math.round(left) + 'px';
        popover.style.top = Math.round(Math.max(viewportPad, top)) + 'px';
    }

    function openHelp(button) {
        var descriptionId = button.getAttribute('data-help-target');
        var description = descriptionId ? document.getElementById(descriptionId) : null;
        if (!description) return;

        ensurePopover();
        popover.textContent = description.textContent.trim().replace(/\s+/g, ' ');
        popover.hidden = false;
        activeButton = button;
        button.setAttribute('aria-expanded', 'true');
        button.setAttribute('aria-controls', popover.id);
        positionPopover(button);
    }

    document.addEventListener('click', function (event) {
        var button = event.target.closest('.analysis-help');
        if (button) {
            event.preventDefault();
            event.stopPropagation();
            if (button === activeButton) closeHelp();
            else {
                closeHelp();
                openHelp(button);
            }
            return;
        }
        if (popover && !popover.contains(event.target)) closeHelp();
    });

    document.addEventListener('keydown', function (event) {
        if (event.key === 'Escape' && activeButton) {
            var button = activeButton;
            closeHelp();
            button.focus();
        }
    });

    window.addEventListener('resize', closeHelp);
    window.addEventListener('scroll', closeHelp, true);
}());
