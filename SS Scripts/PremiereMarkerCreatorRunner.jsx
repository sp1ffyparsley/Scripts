// @target premierepro-24.0
(function () {
    try {
        var here = new File($.fileName);
        var targetPath = here.parent.fsName + '/Premiere Marker Cutting scripts/premiere_marker_creator.jsx';
        targetPath = targetPath.replace(/\\/g, '/');
        var target = new File(targetPath);
        if (!target.exists) {
            alert('Marker script not found:\n' + targetPath);
            return;
        }
        $.evalFile(target);
    } catch (err) {
        alert('Error launching marker script:\n' + err);
    }
}());

