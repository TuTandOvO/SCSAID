(function () {
    "use strict";

    var releases = Array.prototype.slice.call(document.querySelectorAll("[data-release]"));
    var timeline = document.querySelector(".changelog-timeline__nav");

    if (!releases.length || !timeline) {
        return;
    }

    var links = Array.prototype.slice.call(timeline.querySelectorAll("a[href^='#release-']"));
    var linkById = {};

    links.forEach(function (link) {
        linkById[link.getAttribute("href").slice(1)] = link;
    });

    function activate(id) {
        links.forEach(function (link) {
            var active = link === linkById[id];
            link.classList.toggle("is-active", active);
            if (active) {
                link.setAttribute("aria-current", "true");
                if (window.matchMedia("(max-width: 760px)").matches) {
                    link.scrollIntoView({ behavior: "smooth", block: "nearest", inline: "center" });
                }
            } else {
                link.removeAttribute("aria-current");
            }
        });
    }

    links.forEach(function (link) {
        link.addEventListener("click", function () {
            activate(link.getAttribute("href").slice(1));
        });
    });

    if (!("IntersectionObserver" in window)) {
        return;
    }

    var observer = new IntersectionObserver(function (entries) {
        var visible = entries
            .filter(function (entry) { return entry.isIntersecting; })
            .sort(function (a, b) { return a.boundingClientRect.top - b.boundingClientRect.top; });

        if (visible.length) {
            activate(visible[0].target.id);
        }
    }, {
        rootMargin: "-18% 0px -68% 0px",
        threshold: 0
    });

    releases.forEach(function (release) {
        observer.observe(release);
    });
}());
