(function (window, document) {
    "use strict";

    var STORAGE_KEY = "scsaid.preferences.v1";
    var NOTICE_KEY = "scsaid.storage-notice.v1";
    var allowedKeys = { species: true, hidePseudogenes: true };
    allowedKeys.psospotterMode = true;
    allowedKeys.psospotterSpecies = true;
    allowedKeys.psospotterDirection = true;
    allowedKeys.psospotterPanelK = true;
    allowedKeys.psospotterGeneList = true;

    function storageAvailable() {
        try {
            var probe = "__scsaid_storage_probe__";
            window.localStorage.setItem(probe, probe);
            window.localStorage.removeItem(probe);
            return true;
        } catch (error) {
            return false;
        }
    }

    var available = storageAvailable();

    function readAll() {
        if (!available) return {};
        try {
            var parsed = JSON.parse(window.localStorage.getItem(STORAGE_KEY) || "{}");
            return parsed && typeof parsed === "object" && !Array.isArray(parsed) ? parsed : {};
        } catch (error) {
            return {};
        }
    }

    function writeAll(values) {
        if (!available) return false;
        try {
            window.localStorage.setItem(STORAGE_KEY, JSON.stringify(values));
            return true;
        } catch (error) {
            return false;
        }
    }

    function get(name, fallback) {
        if (!allowedKeys[name]) return fallback;
        var values = readAll();
        return Object.prototype.hasOwnProperty.call(values, name) ? values[name] : fallback;
    }

    function set(name, value) {
        if (!allowedKeys[name]) return false;
        var values = readAll();
        values[name] = value;
        return writeAll(values);
    }

    function remove(name) {
        if (!allowedKeys[name]) return false;
        var values = readAll();
        delete values[name];
        return writeAll(values);
    }

    function clear() {
        if (!available) return false;
        try {
            window.localStorage.removeItem(STORAGE_KEY);
            document.dispatchEvent(new CustomEvent("scsaid:preferences-cleared"));
            return true;
        } catch (error) {
            return false;
        }
    }

    function applyControl(control) {
        var key = control.getAttribute("data-preference-key");
        var stored = get(key, null);
        if (stored === null || stored === undefined) return;

        if (control.type === "radio") {
            control.checked = String(control.value) === String(stored);
        } else if (control.type === "checkbox") {
            control.checked = stored === true;
        } else {
            control.value = String(stored);
        }
    }

    function storeControl(control) {
        var key = control.getAttribute("data-preference-key");
        if (control.type === "radio") {
            if (control.checked) set(key, control.value);
        } else if (control.type === "checkbox") {
            set(key, control.checked);
        } else {
            set(key, control.value);
        }
    }

    function bindControls() {
        var controls = document.querySelectorAll("[data-preference-key]");
        for (var i = 0; i < controls.length; i++) {
            applyControl(controls[i]);
            controls[i].addEventListener("change", function () { storeControl(this); });
        }
    }

    function bindNotice() {
        var notice = document.getElementById("storage-notice");
        var dismiss = document.getElementById("storage-notice-dismiss");
        if (!notice || !dismiss) return;

        var acknowledged = false;
        if (available) {
            try { acknowledged = window.localStorage.getItem(NOTICE_KEY) === "acknowledged"; }
            catch (error) { acknowledged = false; }
        }
        if (!acknowledged) notice.hidden = false;

        dismiss.addEventListener("click", function () {
            notice.hidden = true;
            if (available) {
                try { window.localStorage.setItem(NOTICE_KEY, "acknowledged"); }
                catch (error) { /* The notice can still be dismissed for this page view. */ }
            }
        });
    }

    function bindResetButtons() {
        var buttons = document.querySelectorAll("[data-reset-preferences]");
        for (var i = 0; i < buttons.length; i++) {
            buttons[i].addEventListener("click", function () {
                var statusId = this.getAttribute("aria-describedby");
                var status = statusId ? document.getElementById(statusId) : null;
                var cleared = clear();
                if (status) {
                    status.textContent = cleared
                        ? "Saved interface preferences have been cleared."
                        : "Preferences could not be cleared in this browser.";
                }
            });
        }
    }

    window.ScsaidPreferences = {
        available: available,
        get: get,
        set: set,
        remove: remove,
        clear: clear
    };

    document.addEventListener("DOMContentLoaded", function () {
        bindControls();
        bindNotice();
        bindResetButtons();
    });
})(window, document);
