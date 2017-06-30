let Cr;
window.Cruncher = Cr = window.Cruncher || {};

CodeMirror.TextMarker.prototype.toSerializable = function() {
  if (
    this.className == null ||
    (this.className.indexOf("connected-number") !== 0 &&
      this.className !== "free-number" &&
      this.className !== "locked-number")
  ) {
    return null;
  }

  let { from, to } = this.find();

  return {
    from,
    to,
    cid: this.cid,
    options: {
      className: this.className,
      inclusiveLeft: this.inclusiveLeft,
      inclusiveRight: this.inclusiveRight,
      atomic: this.atomic
    }
  };
};

$(function() {
  // Initialize Firebase
  let config = {
    apiKey: "AIzaSyBbisLJOm0QPhkeMCpPXLtlW-_PZd2sHUY",
    authDomain: "cruncher-4719b.firebaseapp.com",
    databaseURL: "https://cruncher-4719b.firebaseio.com",
    storageBucket: "cruncher-4719b.appspot.com",
    messagingSenderId: "715362151432"
  };
  firebase.initializeApp(config);
  let db = firebase.database();

  let serializeDoc = () =>
    JSON.stringify(
      {
        version: Cr.VERSION,
        title: Cr.editor.doc.title,
        text: Cr.editor.getValue(),
        marks: Array.from(
          Array.from(Cr.editor.getAllMarks()).map(mark => mark.toSerializable())
        )
          .filter(m => m != null)
          .map(m => m)
      },
      null,
      2
    );

  let deserializeDoc = function(data, key, mode, settings) {
    if (mode == null) {
      mode = "edit";
    }
    data = JSON.parse(data);
    let doc = CodeMirror.Doc(data.text, "cruncher");
    if (key == null) {
      ({ key } = db.ref("docs").push());
    }
    doc.key = key;
    doc.title = data.title;
    doc.settings = settings;
    Cr.editor.swapDoc(doc);

    for (let mark of Array.from(data.marks)) {
      let newMark = Cr.editor.markText(mark.from, mark.to, mark.options);
      newMark.cid = mark.cid;
    }

    return Cr.swappedDoc(mode);
  };

  $(".new-doc").click(() => Cr.newDoc());

  $(".import-doc").click(() => $("#file-chooser").click());

  $("#file-chooser").change(function(event) {
    let file = event.target.files[0];
    let reader = new FileReader();
    reader.onload = function() {
      try {
        return deserializeDoc(reader.result);
      } catch (e) {
        return alert("Error loading file.");
      }
    };

    reader.readAsText(file);
    return (this.value = null);
  });

  $(".export-doc").click(function() {
    let blob = new Blob([serializeDoc()], {
      type: "text/plain; charset=utf-8"
    });
    let { title } = Cr.editor.doc;
    title = title.match(/\.[Cc][Rr]$/) ? title : title + ".cr";
    return saveAs(blob, title);
  });

  $(".save-doc").click(() => Cr.saveDoc(Cr.editor.doc));

  $(".publish-doc").click(function() {
    // FIXME: Finish this move to Firebase.
    alert("Note: Publishing doesn't really work right now.");
    return $("#publish").modal("show");
  });

  $(".do-publish").click(function() {
    let settings = {
      editable: $(".publish-editable").prop("checked"),
      scrubbable: $(".publish-scrubbable").prop("checked"),
      gutter: $(".publish-gutter").prop("checked"),
      hints: $(".publish-hints").prop("checked")
    };

    return Cr.publishDoc(Cr.editor.doc.uid, settings, {
      success(publishId) {
        let baseUrl = window.location.href.match(/(^[^\?]*)/)[1];
        let viewUrl = baseUrl + "?/view/" + publishId;
        let embedUrl = baseUrl + "?/embed/" + publishId;

        $(".view-url").val(viewUrl);
        $(".embed-code").val(`<iframe src="${embedUrl}"></iframe>`);
        return $(".embed-preview").attr("src", embedUrl);
      }
    });
  });

  Cr.newDoc = function() {
    let doc = CodeMirror.Doc("", "cruncher");
    doc.key = db.ref("docs").push().key;
    doc.title = "Untitled";
    Cr.editor.swapDoc(doc);
    return Cr.swappedDoc();
  };

  Cr.loadView = viewKey =>
    db
      .ref(`docs/${viewKey}`)
      .once("value")
      .then(function(response) {
        let val = response.val();
        return deserializeDoc(val.data, viewKey, "view", val.settings);
      })
      .catch(function(error) {
        alert(`Failed to load published document: ${error}`);
        return Cr.newDoc();
      });

  Cr.loadEmbed = viewid => // FIXME merge with loadView
    Parse.Cloud.run(
      "getPublish",
      { publishId: viewid },
      {
        success(response) {
          return deserializeDoc(
            response.data,
            viewid,
            "embed",
            response.settings
          );
        },

        error(response, error) {
          alert(`Failed to load published document: ${error}`);
          return Cr.newDoc();
        }
      }
    );

  Cr.loadExample = function(tid) {
    $("#loading").fadeIn();

    return $.get(`https://cruncher-examples.s3.amazonaws.com/${tid}`, function(
      data
    ) {
      $("#loading").fadeOut();
      return deserializeDoc(data, null);
    }).fail(function() {
      $("#loading").fadeOut();
      return Cr.newDoc();
    });
  };

  Cr.loadDoc = function(key) {
    $("#loading").fadeIn();

    if (key.substring(0, "examples/".length) === "examples/") {
      Cr.loadExample(key.substring("examples/".length));
      return;
    }

    return db
      .ref(`docs/${key}`)
      .once("value")
      .then(function(response) {
        $("#loading").fadeOut();
        let val = response.val();
        return deserializeDoc(val, key);
      })
      .catch(function(error) {
        console.log(error);
        $("#loading").fadeOut();
        return Cr.newDoc();
      });
  };

  Cr.saveDoc = function(doc) {
    db.ref(`docs/${doc.key}`).set(serializeDoc(doc));
    return Cr.markClean();
  };

  return (Cr.publishDoc = function(callbacks) {
    let publishedKey = db.ref("publishedDocs").push().key;
    db.ref(`publishedDocSaveKeys/${publishedKey}`).set();

    db.ref(`publishedDocs/${publishedKey}`);
    return Parse.Cloud.run(
      "publish",
      { saveId: uid, data: serializeDoc(), settings },
      {
        success(response) {
          callbacks.success(response.publishId);
          return console.log("published", response);
        },

        error(response, error) {
          callbacks.error(response, error);
          return console.log("error", response, error);
        }
      }
    );
  });
});
