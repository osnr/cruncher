window.Cruncher = Cr = window.Cruncher || {};

Cr.NumberWidget = class NumberWidget {
  constructor(value, pos, onControlChange) {
    this.setFreeNumber = this.setFreeNumber.bind(this);
    this.unsetFreeNumber = this.unsetFreeNumber.bind(this);
    let mark;
    this.value = value;
    this.pos = pos;
    this.onControlChange = onControlChange;
    this.$numberWidget = $(
      '<div class="number-widget">' +
        '<a id="connect"><i class="fa fa-circle-o"></i></a>' +
        '<a id="computerize"><i class="fa fa-pencil-square"></i></a>' +
        "</div>"
    );

    this.cid = Cr.getValueCid(this.value);
    if (this.cid != null) {
      this.$numberWidget
        .find("#connect i")
        .addClass("fa-circle")
        .removeClass("fa-circle-o");
    }

    if (typeof this.value.num === "function") {
      // this is a free number
      this.mark = (() => {
        let result = [];
        for (mark of Array.from(
          Cr.editor.findMarksAt(Cr.valueFrom(this.value))
        )) {
          if (mark.className === "free-number") {
            result.push(mark);
          }
        }
        return result;
      })()[0];
    }
  }

  show() {
    $(".number-widget").remove();

    Cr.editor.addWidget(
      {
        line: this.pos.line,
        ch: this.value.start
      },
      this.$numberWidget[0]
    );

    this.$number = $(".CodeMirror-code .hovering-number");

    let offset = this.$number.offset();
    this.$numberWidget //.width(($ this).width())
      .offset({
        top: offset.top + this.$number.height(),
        left: offset.left - 3
      })
      .mouseenter(() => {
        return this.$numberWidget.stop(true).animate({ opacity: 100 });
      })
      .on("click", "#computerize", () => {
        this.setFreeNumber();

        return this.onControlChange(this.pos.line);
      })
      .on("click", "#humanize", () => {
        this.unsetFreeNumber();

        return this.onControlChange(this.pos.line);
      })
      .on("mousedown", "#connect", event => {
        let fromCoords = Cr.editor.charCoords(Cr.valueFrom(this.value));
        let toCoords = Cr.editor.charCoords(Cr.valueTo(this.value));

        if (this.cid == null) {
          this.cid = Cr.newCid();
        }

        return Cr.startConnect(
          this.cid,
          this.value,
          (toCoords.left + fromCoords.left) / 2,
          (fromCoords.bottom + fromCoords.top) / 2
        );
      });

    if (this.mark != null) {
      return this.setFreeNumber($("#computerize"));
    }
  }

  setFreeNumber($target) {
    if (this.mark == null) {
      this.mark = Cr.markAsFree(
        Cr.valueFrom(this.value),
        Cr.valueTo(this.value)
      );
    }

    $("#connect i.fa-circle-o")
      .removeClass("fa-circle-o")
      .addClass("fa-arrow-circle-down");

    $("#computerize")
      .attr("id", "humanize")
      .find("i")
      .removeClass("fa-pencil-square")
      .addClass("fa-cogs");
    return this.$numberWidget.addClass("free-number-widget");
  }

  unsetFreeNumber($target) {
    if (this.mark != null) {
      this.mark.clear();
      this.mark = null;
    }

    $("#humanize")
      .attr("id", "computerize")
      .find("i")
      .removeClass("fa-cogs")
      .addClass("fa-pencil-square");
    return this.$numberWidget.removeClass("free-number-widget");
  }
};
