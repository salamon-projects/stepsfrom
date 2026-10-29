// Opens the destination filters on wide screens. The HTML keeps them folded
// so that phones see the results first; without JavaScript a tap opens them.
(function () {
  "use strict";

  document.addEventListener("DOMContentLoaded", function () {
    if (!window.matchMedia("(min-width: 64rem)").matches) return;
    Array.prototype.forEach.call(document.querySelectorAll("details[data-open-on-desktop]"), function (details) {
      details.open = true;
    });
  });
})();
