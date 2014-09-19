Parse.Cloud.define("publish", function(request, response) {
    var saveId = request.params.saveId;
    var data = request.params.data;
    var settings = request.params.settings;

    Parse.Cloud.useMasterKey();

    var query = new Parse.Query("Doc");
    var doc;
    query.get(saveId).then(function(as) {
        doc = as; // FIXME is this good practice?

        var publishId = doc.get("publishId");

        var publishQuery = new Parse.Query("PublishDoc");
        if (publishId) {
            return publishQuery.get(publishId);
        } else {
            return new Parse.Object("PublishDoc");
        }
    }).then(function(publishDoc) {
        // check if whether -- if this publishDoc already existed --
        // it's actually keyed to this save; if it's not, the user
        // shouldn't be able to update it
        var publishSaveId = publishDoc.get("saveId");

        if (!publishSaveId || publishSaveId === saveId) {
            return Parse.Promise.as(publishDoc);
        } else {
            return Parse.Promise.error("Not authorized to publish here.");
        }
    }).then(function(publishDoc) {
        publishDoc.set("saveId", saveId);
        publishDoc.set("data", data);
        publishDoc.set("settings", settings);

        return publishDoc.save();

    }).then(function(publishDoc) {
        doc.set("publishId", publishDoc.id);
        doc.set("data", data);

        return doc.save();

    }).then(function(doc) {
        response.success({ publishId: doc.get("publishId") });

    }, function(error) {
        response.error(error);
    });
});

Parse.Cloud.define("getPublish", function(request, response) {
    var publishId = request.params.publishId;

    var query = new Parse.Query("PublishDoc");
    query.get(publishId, {
        useMasterKey: true,

        success: function(publishDoc) {
            response.success({ data: publishDoc.get("data"), settings: publishDoc.get("settings") });
        },
        error: function(error) {
            response.error(error);
        }
    });
});

