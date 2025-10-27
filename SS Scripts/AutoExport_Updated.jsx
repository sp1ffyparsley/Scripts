// @target premierepro-24.0
/**
 * Auto-export clips from the first video track through Adobe Media Encoder.
 * - Output folder defaults to the current user's Downloads directory.
 * - User selects one of the preconfigured AME presets (provided by AutoHotkey UI).
 * - Each clip on V1 is queued with its own file name (sanitised).
 */

(function () {
    var DEFAULT_PRESET_KEY = "match_source_high";
    var PRESET_MAP = {
        prores4444_mxf: {
            name: "Apple ProRes 4444 (MXF)",
            path: "C:/Program Files/Adobe/Adobe Media Encoder 2024/MediaIO/systempresets/4D584620_504D5846/Apple ProRes 4444.epr",
            extension: ".mxf"
        },
        match_source_high: {
            name: "Match Source - High Bitrate (.mp4)",
            path: "C:/Program Files/Adobe/Adobe Premiere Pro 2024/MediaIO/systempresets/4E49434B_48323634/01 - Match Source - High bitrate.epr",
            extension: ".mp4"
        },
        match_source_low: {
            name: "Match Source - Low Bitrate (.mp4)",
            path: "C:/Program Files/Adobe/Adobe Premiere Pro 2024/MediaIO/systempresets/4E49434B_48323634/02 - Match Source - Low bitrate.epr",
            extension: ".mp4"
        }
    };

    function exitWithError(msg) {
        if (msg) {
            alert(msg);
        }
        throw new Error(msg || "Auto export aborted.");
    }

    function getDownloadsFolder() {
        var folder = new Folder("~/Downloads");
        if (!folder.exists) {
            folder = Folder.selectDialog("Downloads folder not found. Select an export folder.");
        }
        return folder;
    }

    function sanitiseName(raw) {
        var safe = raw || "clip";
        safe = safe.replace(/[\\\/:*?"<>|]/g, "_");
        safe = safe.replace(/\s+/g, "_");
        return safe || "clip";
    }

    function ensureUniqueFile(basePath) {
        var candidate = new File(basePath);
        if (!candidate.exists) {
            return candidate;
        }
        var counter = 1;
        var parts = basePath.match(/^(.*?)(?:\.(\w+))?$/);
        var prefix = parts[1];
        var ext = parts[2] ? "." + parts[2] : "";
        while (true) {
            candidate = new File(prefix + "_" + counter + ext);
            if (!candidate.exists) {
                return candidate;
            }
            counter += 1;
        }
    }

    function resolveConfigPresetKey() {
        var key = null;
        try {
            var scriptFile = new File($.fileName);
            var configFile = new File(scriptFile.parent.fsName + "/support/cache/autoexport_selection.txt");
            if (configFile.exists) {
                if (configFile.open("r")) {
                    key = configFile.read();
                    configFile.close();
                }
                try {
                    configFile.remove();
                } catch (removeErr) {
                    // Ignore issues removing the cached selection.
                }
            }
        } catch (e) {
            key = null;
        }

        if (key) {
            key = key.replace(/\s+/g, "").toLowerCase();
        }
        if (key && PRESET_MAP.hasOwnProperty(key)) {
            return key;
        }
        return DEFAULT_PRESET_KEY;
    }

    var presetKey = resolveConfigPresetKey();
    var preset = PRESET_MAP[presetKey];
    if (!preset) {
        exitWithError("Export cancelled: preset selection invalid.");
        return;
    }

    var presetFile = new File(preset.path);
    if (!presetFile.exists) {
        exitWithError("Preset file not found:\n" + preset.path);
        return;
    }

    var outputFolder = getDownloadsFolder();
    if (!outputFolder) {
        exitWithError("Export cancelled: no output folder available.");
        return;
    }

    if (!app.project || !app.project.activeSequence) {
        exitWithError("No active sequence found.");
        return;
    }
    var sequence = app.project.activeSequence;

    if (!sequence.videoTracks || sequence.videoTracks.numTracks < 1) {
        exitWithError("No video tracks detected in the active sequence.");
        return;
    }
    var track = sequence.videoTracks[0];
    if (!track.clips || track.clips.numItems === 0) {
        exitWithError("No clips detected on the first video track.");
        return;
    }

    var ticksPerFrame = Number(sequence.timebase);
    var ticksPerSecond = 254016000000;
    var secondsPerFrame = ticksPerFrame / ticksPerSecond;

    app.encoder.launchEncoder();

    for (var i = 0; i < track.clips.numItems; i++) {
        var clip = track.clips[i];
        var inSec = clip.start.seconds;
        var outSec = Math.max(0, clip.end.seconds - secondsPerFrame);

        sequence.setInPoint(inSec);
        sequence.setOutPoint(outSec);

        var clipName = clip.name || ("clip_" + (i + 1));
        clipName = sanitiseName(clipName);
        var targetPath = outputFolder.fsName + "/" + clipName + preset.extension;
        var outputFile = ensureUniqueFile(targetPath);

        try {
            app.encoder.encodeSequence(sequence, outputFile.fsName, presetFile.fsName, 1, 0);
            $.writeln("Queued export for " + outputFile.fsName + " using " + preset.name);
        } catch (e) {
            $.writeln("Failed to queue " + clipName + ": " + e);
        }
    }

    app.encoder.startBatch();
    alert("All clips queued in Adobe Media Encoder using " + preset.name + ".");
}());
