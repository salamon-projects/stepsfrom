// Stay22's map with live prices (shared/_stay22_map). It is third-party
// content, so the page holds only its address; the iframe is created when
// the visitor clicks the button. Without JavaScript the section stays hidden.
(function () {
  "use strict";

  document.addEventListener("DOMContentLoaded", function () {
    Array.prototype.forEach.call(document.querySelectorAll("[data-stay22-map]"), function (section) {
      var button = section.querySelector(".stay22-map__button");
      var holder = section.querySelector(".stay22-map__holder");
      if (!button || !holder) return;

      section.hidden = false;
      button.addEventListener("click", function () {
        var frame = document.createElement("iframe");
        frame.className = "stay22-map__frame";
        frame.title = section.getAttribute("data-stay22-map-title");
        frame.loading = "lazy";
        frame.referrerPolicy = "strict-origin-when-cross-origin";
        frame.src = section.getAttribute("data-stay22-map");
        holder.appendChild(frame);
        button.hidden = true;
        frame.focus();
      });
    });
  });
})();
