// Calendar and guest steppers for the stay fields (shared/_stay_fields).
// Progressive enhancement: without JavaScript the form keeps the browser's
// date inputs and selects, and both versions submit the same parameters.
(function () {
  "use strict";

  var WIDE = "(min-width: 48rem)";
  var LOCALE = "en-GB";
  var formats = {
    short: new Intl.DateTimeFormat(LOCALE, { weekday: "short", day: "numeric", month: "short" }),
    full: new Intl.DateTimeFormat(LOCALE, { weekday: "long", day: "numeric", month: "long", year: "numeric" }),
    month: new Intl.DateTimeFormat(LOCALE, { month: "long", year: "numeric" }),
    weekday: new Intl.DateTimeFormat(LOCALE, { weekday: "short" })
  };

  // Dates are local midnights; ISO strings are built by hand so time zones
  // never shift a day.
  function pad(n) { return n < 10 ? "0" + n : String(n); }
  function iso(date) { return date.getFullYear() + "-" + pad(date.getMonth() + 1) + "-" + pad(date.getDate()); }
  function parse(value) {
    var match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value || "");
    return match ? new Date(+match[1], +match[2] - 1, +match[3]) : null;
  }
  function addDays(date, days) { return new Date(date.getFullYear(), date.getMonth(), date.getDate() + days); }
  function monthStart(date, offset) { return new Date(date.getFullYear(), date.getMonth() + (offset || 0), 1); }
  function nights(from, to) { return Math.round((to - from) / 86400000); }
  function el(tag, className, text) {
    var node = document.createElement(tag);
    if (className) node.className = className;
    if (text != null) node.textContent = text;
    return node;
  }

  // --- Calendar ------------------------------------------------------------

  function Calendar(startInput, endInput) {
    var now = new Date();
    this.labels = JSON.parse(startInput.getAttribute("data-calendar"));
    this.today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    this.min = parse(startInput.min) || this.today;
    this.max = addDays(this.today, 540);
    this.inputs = { start: startInput, end: endInput };
    this.start = parse(startInput.value);
    this.end = parse(endInput.value);
    this.anchor = startInput.closest(".field");
    this.triggers = { start: this.trigger(startInput, "start"), end: this.trigger(endInput, "end") };
    this.build();
    this.update();
  }

  Calendar.prototype.trigger = function (input, which) {
    var button = el("button", "date-trigger");
    button.type = "button";
    button.id = input.id;
    button.setAttribute("aria-haspopup", "dialog");
    button.setAttribute("aria-expanded", "false");
    input.id = input.id + "_value";
    input.type = "hidden";
    input.parentNode.insertBefore(button, input.nextSibling);
    input.closest(".field").classList.add("field--enhanced");
    button.addEventListener("click", this.open.bind(this, which));
    return button;
  };

  Calendar.prototype.build = function () {
    var self = this;
    this.layer = el("div", "calendar-layer");
    this.layer.hidden = true;
    this.backdrop = el("div", "calendar-layer__backdrop");
    this.panel = el("div", "calendar");
    this.panel.setAttribute("role", "dialog");
    this.panel.setAttribute("aria-label", this.labels.dialog);

    var head = el("div", "calendar__head");
    this.prev = el("button", "calendar__nav calendar__nav--prev");
    this.next = el("button", "calendar__nav calendar__nav--next");
    [ [ this.prev, this.labels.previous_month, -1 ], [ this.next, this.labels.next_month, 1 ] ].forEach(function (nav) {
      nav[0].type = "button";
      nav[0].setAttribute("aria-label", nav[1]);
      nav[0].addEventListener("click", function () { self.shift(nav[2]); });
      head.appendChild(nav[0]);
    });

    this.months = el("div", "calendar__months");
    this.months.addEventListener("click", function (event) {
      var day = event.target.closest(".calendar__day");
      if (day && day.getAttribute("aria-disabled") !== "true") self.select(parse(day.getAttribute("data-date")));
    });
    this.months.addEventListener("mouseover", function (event) {
      var day = event.target.closest(".calendar__day");
      if (day) self.preview(parse(day.getAttribute("data-date")));
    });
    this.months.addEventListener("mouseleave", function () { self.preview(null); });
    this.months.addEventListener("keydown", this.keydown.bind(this));

    var foot = el("div", "calendar__foot");
    this.status = el("p", "calendar__status");
    this.status.setAttribute("aria-live", "polite");
    var clear = el("button", "calendar__clear", this.labels.clear);
    var done = el("button", "button button--primary calendar__done", this.labels.done);
    clear.type = done.type = "button";
    clear.addEventListener("click", function () { self.clear(); });
    done.addEventListener("click", function () { self.close(true); });
    foot.appendChild(this.status);
    foot.appendChild(clear);
    foot.appendChild(done);

    this.panel.appendChild(head);
    this.panel.appendChild(this.months);
    this.panel.appendChild(foot);
    this.layer.appendChild(this.backdrop);
    this.layer.appendChild(this.panel);
    document.body.appendChild(this.layer);

    this.backdrop.addEventListener("click", function () { self.close(false); });
    // Tabbing out of the panel closes it, as clicking elsewhere does.
    this.panel.addEventListener("focusout", function (event) {
      var next = event.relatedTarget;
      if (next && !self.panel.contains(next) && next !== self.triggers.start && next !== self.triggers.end) self.close(false);
    });
    this.onDocument = function (event) {
      if (!self.panel.contains(event.target) && event.target !== self.triggers.start &&
          event.target !== self.triggers.end && !self.triggers.start.contains(event.target) &&
          !self.triggers.end.contains(event.target)) self.close(false);
    };
    this.onKey = function (event) {
      if (event.key === "Escape") { event.preventDefault(); self.close(true); }
    };
    this.onResize = function () { self.render(); self.place(); };
  };

  Calendar.prototype.monthCount = function () {
    return window.matchMedia(WIDE).matches ? 2 : 1;
  };

  Calendar.prototype.open = function (which) {
    if (!this.layer.hidden && this.selecting === which) return this.close(true);
    this.selecting = which === "end" && this.start ? "end" : "start";
    this.focusDate = this.clamp((this.selecting === "end" ? this.end || addDays(this.start, 1) : this.start) || this.min);
    this.view = monthStart(this.selecting === "end" && this.start ? this.start : this.focusDate);
    this.layer.hidden = false;
    document.documentElement.classList.toggle("calendar-open", !window.matchMedia(WIDE).matches);
    this.render();
    this.place();
    this.update();
    this.focusDay();
    document.addEventListener("mousedown", this.onDocument);
    document.addEventListener("keydown", this.onKey);
    window.addEventListener("resize", this.onResize);
  };

  Calendar.prototype.close = function (returnFocus) {
    if (this.layer.hidden) return;
    this.layer.hidden = true;
    document.documentElement.classList.remove("calendar-open");
    document.removeEventListener("mousedown", this.onDocument);
    document.removeEventListener("keydown", this.onKey);
    window.removeEventListener("resize", this.onResize);
    var trigger = this.triggers[this.selecting];
    this.selecting = null;
    this.update();
    if (returnFocus) trigger.focus();
  };

  // Wide screens: a panel under the date fields. Phones: a bottom sheet (CSS).
  Calendar.prototype.place = function () {
    if (!window.matchMedia(WIDE).matches) {
      this.panel.style.removeProperty("top");
      this.panel.style.removeProperty("left");
      return;
    }
    var rect = this.anchor.getBoundingClientRect();
    var width = this.panel.offsetWidth;
    var left = Math.max(16, Math.min(rect.left, document.documentElement.clientWidth - width - 16));
    this.panel.style.top = (rect.bottom + window.scrollY + 8) + "px";
    this.panel.style.left = (left + window.scrollX) + "px";
  };

  Calendar.prototype.shift = function (months) {
    this.view = monthStart(this.view, months);
    var last = monthStart(this.view, this.monthCount() - 1);
    if (this.focusDate < this.view || this.focusDate >= monthStart(last, 1)) {
      this.focusDate = this.clamp(new Date(this.view.getFullYear(), this.view.getMonth(), Math.min(this.focusDate.getDate(), 28)));
    }
    this.render();
  };

  Calendar.prototype.clamp = function (date) {
    return date < this.min ? this.min : date > this.max ? this.max : date;
  };

  Calendar.prototype.disabled = function (date) {
    if (date < this.min || date > this.max) return true;
    return this.selecting === "end" && this.start && date > this.start &&
      nights(this.start, date) > this.labels.max_nights;
  };

  Calendar.prototype.render = function () {
    var count = this.monthCount();
    var firstAllowed = monthStart(this.min);
    if (this.view < firstAllowed) this.view = firstAllowed;
    this.months.textContent = "";
    for (var i = 0; i < count; i++) this.months.appendChild(this.month(monthStart(this.view, i)));
    this.prev.disabled = this.view <= firstAllowed;
    this.next.disabled = monthStart(this.view, count) > this.max;
    this.mark();
  };

  Calendar.prototype.month = function (first) {
    var wrapper = el("div", "calendar__month");
    var title = el("h2", "calendar__title", formats.month.format(first));
    title.id = "calendar-" + iso(first);
    var grid = el("table", "calendar__grid");
    grid.setAttribute("role", "grid");
    grid.setAttribute("aria-labelledby", title.id);

    var headRow = el("tr");
    for (var d = 0; d < 7; d++) {
      var monday = new Date(2024, 0, 1 + d);
      var th = el("th", null, formats.weekday.format(monday).slice(0, 2));
      th.setAttribute("scope", "col");
      th.setAttribute("abbr", formats.weekday.format(monday));
      headRow.appendChild(th);
    }
    var thead = el("thead");
    thead.appendChild(headRow);
    grid.appendChild(thead);

    var body = el("tbody");
    var offset = (first.getDay() + 6) % 7;
    var days = new Date(first.getFullYear(), first.getMonth() + 1, 0).getDate();
    var row = el("tr");
    for (var blank = 0; blank < offset; blank++) row.appendChild(el("td"));
    for (var day = 1; day <= days; day++) {
      var date = new Date(first.getFullYear(), first.getMonth(), day);
      var cell = el("td");
      var button = el("button", "calendar__day", String(day));
      button.type = "button";
      button.tabIndex = -1;
      button.setAttribute("data-date", iso(date));
      button.setAttribute("aria-label", formats.full.format(date));
      if (date.getTime() === this.today.getTime()) button.classList.add("is-today");
      cell.appendChild(button);
      row.appendChild(cell);
      if ((offset + day) % 7 === 0) { body.appendChild(row); row = el("tr"); }
    }
    if (row.children.length) {
      while (row.children.length < 7) row.appendChild(el("td"));
      body.appendChild(row);
    }
    grid.appendChild(body);
    wrapper.appendChild(title);
    wrapper.appendChild(grid);
    return wrapper;
  };

  // Selection, range and disabled state of every visible day.
  Calendar.prototype.mark = function () {
    var self = this;
    var rangeEnd = this.end || this.previewEnd;
    Array.prototype.forEach.call(this.months.querySelectorAll(".calendar__day"), function (button) {
      var date = parse(button.getAttribute("data-date"));
      var time = date.getTime();
      var isStart = self.start && time === self.start.getTime();
      var isEnd = rangeEnd && time === rangeEnd.getTime();
      button.classList.toggle("is-start", !!isStart);
      button.classList.toggle("is-end", !!isEnd && !!self.start);
      button.classList.toggle("is-range", !!(self.start && rangeEnd && date > self.start && date < rangeEnd));
      button.classList.toggle("is-preview", !self.end && !!self.previewEnd);
      button.setAttribute("aria-pressed", isStart || (isEnd && self.end) ? "true" : "false");
      button.setAttribute("aria-disabled", self.disabled(date) ? "true" : "false");
      button.tabIndex = self.focusDate && time === self.focusDate.getTime() ? 0 : -1;
    });
  };

  Calendar.prototype.preview = function (date) {
    var valid = date && this.selecting === "end" && this.start && !this.end && date > this.start && !this.disabled(date);
    this.previewEnd = valid ? date : null;
    this.mark();
  };

  Calendar.prototype.select = function (date) {
    this.focusDate = date;
    if (this.selecting === "end" && this.start && date > this.start) {
      this.end = date;
      this.previewEnd = null;
      this.commit();
      this.close(false);
      this.triggers.end.focus();
      return;
    }
    this.start = date;
    if (this.end && (this.end <= date || nights(date, this.end) > this.labels.max_nights)) this.end = null;
    this.selecting = "end";
    this.commit();
    this.render();
    this.focusDay();
  };

  Calendar.prototype.clear = function () {
    this.start = this.end = this.previewEnd = null;
    this.selecting = "start";
    this.commit();
    this.render();
    this.focusDay();
  };

  Calendar.prototype.commit = function () {
    this.inputs.start.value = this.start ? iso(this.start) : "";
    this.inputs.end.value = this.end ? iso(this.end) : "";
    this.update();
  };

  // Trigger texts, which trigger is active, and the status line.
  Calendar.prototype.update = function () {
    var self = this;
    [ "start", "end" ].forEach(function (which) {
      var button = self.triggers[which];
      var date = self[which];
      button.textContent = "";
      button.appendChild(el("span", date ? "date-trigger__value" : "date-trigger__placeholder",
        date ? formats.short.format(date) : self.labels.add_date));
      button.classList.toggle("is-active", self.selecting === which);
      button.setAttribute("aria-expanded", self.selecting === which ? "true" : "false");
    });

    if (this.start && this.end) {
      var count = nights(this.start, this.end);
      this.status.textContent = count + " " + (count === 1 ? this.labels.night : this.labels.nights) +
        " · " + formats.short.format(this.start) + " – " + formats.short.format(this.end);
    } else {
      this.status.textContent = this.start ? this.labels.choose_check_out : this.labels.choose_check_in;
    }
  };

  Calendar.prototype.focusDay = function () {
    var button = this.months.querySelector('[data-date="' + iso(this.focusDate) + '"]');
    if (button) button.focus();
  };

  Calendar.prototype.keydown = function (event) {
    var moves = { ArrowLeft: -1, ArrowRight: 1, ArrowUp: -7, ArrowDown: 7 };
    var date = this.focusDate;
    var target;
    if (event.key in moves) {
      target = addDays(date, moves[event.key]);
    } else if (event.key === "PageUp" || event.key === "PageDown") {
      var step = event.key === "PageUp" ? -1 : 1;
      var month = monthStart(date, step);
      var last = new Date(month.getFullYear(), month.getMonth() + 1, 0).getDate();
      target = new Date(month.getFullYear(), month.getMonth(), Math.min(date.getDate(), last));
    } else if (event.key === "Home") {
      target = addDays(date, -((date.getDay() + 6) % 7));
    } else if (event.key === "End") {
      target = addDays(date, 6 - ((date.getDay() + 6) % 7));
    } else {
      return;
    }
    event.preventDefault();
    target = this.clamp(target);
    this.focusDate = target;
    var lastShown = monthStart(this.view, this.monthCount());
    if (target < this.view || target >= lastShown) {
      this.view = target < this.view ? monthStart(target) : monthStart(target, 1 - this.monthCount());
      this.render();
    } else {
      this.mark();
    }
    this.focusDay();
  };

  // --- Steppers ------------------------------------------------------------

  function stepper(select) {
    var field = select.closest(".field");
    var label = field.querySelector("label");
    var texts = JSON.parse(select.getAttribute("data-stepper"));
    var group = el("div", "stepper");
    var minus = el("button", "stepper__button stepper__button--minus");
    var plus = el("button", "stepper__button stepper__button--plus");
    var value = el("output", "stepper__value");

    label.id = select.id + "_label";
    label.removeAttribute("for");
    group.setAttribute("role", "group");
    group.setAttribute("aria-labelledby", label.id);
    value.setAttribute("aria-live", "polite");
    [ [ minus, texts.fewer, -1 ], [ plus, texts.more, 1 ] ].forEach(function (control) {
      control[0].type = "button";
      control[0].setAttribute("aria-label", control[1]);
      control[0].addEventListener("click", function () {
        select.selectedIndex = Math.max(0, Math.min(select.options.length - 1, select.selectedIndex + control[2]));
        select.dispatchEvent(new Event("change", { bubbles: true }));
        refresh();
      });
    });

    function refresh() {
      value.textContent = select.value;
      minus.disabled = select.selectedIndex === 0;
      plus.disabled = select.selectedIndex === select.options.length - 1;
    }

    // The select stays in the form (hidden) so it is still submitted and the
    // CSS that shows one age field per child keeps working.
    select.hidden = true;
    group.appendChild(minus);
    group.appendChild(value);
    group.appendChild(plus);
    select.parentNode.insertBefore(group, select.nextSibling);
    field.classList.add("field--enhanced");
    refresh();
  }

  document.addEventListener("DOMContentLoaded", function () {
    var calendars = [];
    Array.prototype.forEach.call(document.querySelectorAll("input[data-calendar]"), function (startInput) {
      var endInput = startInput.form && startInput.form.querySelector('input[name="check_out"]');
      if (endInput) calendars.push(new Calendar(startInput, endInput));
    });

    // "Add dates" prompts next to offers open the page's calendar (unfolding
    // the filters first); without JavaScript they jump to the date field.
    document.addEventListener("click", function (event) {
      var prompt = event.target.closest("[data-open-calendar]");
      if (!prompt || !calendars.length) return;
      event.preventDefault();
      var trigger = calendars[0].triggers.start;
      var details = trigger.closest("details");
      if (details) details.open = true;
      trigger.scrollIntoView({ block: "center" });
      calendars[0].open("start");
    });
    Array.prototype.forEach.call(document.querySelectorAll("select[data-stepper]"), stepper);
  });
})();
