import QtQuick 2.0;
import MuseScore 1.1;
import QtQuick.Controls 1.2;
import QtQuick.Window 2.2;

MuseScore
{
    property var colors :{
        "red": "#ff0000",
        "blue": "#0000ff",
        "green": "#00ff00",
        "black": "#000"
    }

    property var diffActions: {
        "del": "-",
        "ins": "+",
        "mod": "±",
        "noop": " "
    }

    property var score1;
    property var score2;
    
    /* --- COLOR --- */

    function colorElement(el, _color, beams) {
        if(el.type === Element.CHORD) {
            var notes = el.notes;
            for(var i = 0; i < notes.length; i++)
                colorElement(notes[i], _color, beams);
            if(el.stem)
                el.stem.color = _color;
            if(beams && el.beam)
                el.beam.color = _color;
        }
        else if(el.type === Element.NOTE) {
            el.color = _color;
            if(el.stem)
                el.parent.stem.color = _color;
            if(beams && el.beam)
                el.beam.color = _color;
            if(el.accidental)
                el.accidental.color = _color;
            if(el.elements)
                for(var i = 0; i < el.elements; i++)
                    colorElement(el.elements[i], _color, beams);
        }
        else if(el.type === Element.REST)
            el.color = _color;
        else if(el.color)
            el.color = _color
    }

    function toggleElement(el, show) {
        if(!(show === true || show === false))
            show = false;

        if(el.type === Element.CHORD) {
            var notes = el.notes;
            for(var i = 0; i < notes.length; i++)
                toggleElement(notes[i], show);
            if(el.stem)
                el.stem.visible = show;
            if(el.beam)
                el.beam.visible = show;
            if(el.stemSlash)
                el.stemSlash.visible = show;
        }
        else if(el.type === Element.NOTE) {
            el.visible = show;
            if(el.accidental)
                el.accidental.visible = show;
            for(var i = 0; i < el.elements; i++)
                toggleElement(el.elements[i], show);
            for(var i = 0; i < el.dots; i++)
                toggleElement(el.dots[i], show);
            if(el.accidental)
                toggleElement(el.accidental.color, show);
        }
        else if(el.type === Element.REST)
            el.visible = show;
        else if(el.visible !== null && el.visible !== undefined)
            el.visible = show;
    }

    function colorMeasure(measure, _color) {
        var seg = measure.firstSegment;

        while(seg) {
            colorElement(seg.elementAt(0), _color, true);
            seg = seg.nextInMeasure;
        }
    }

    function toggleMeasure(measure, show) {
        var seg = measure.firstSegment;
        while(seg) {
            toggleElement(seg.elementAt(0), show);
            seg = seg.nextInMeasure;
        }
    }

    function resetColors(score) {
        var cur = score.newCursor();
        cur.track = 0;
        cur.rewind(0);

        while(cur.measure) {
            colorMeasure(cur.measure, colors.black);
            toggleMeasure(cur.measure, true);
            cur.nextMeasure();
        }
    }

    function highlightMeasures(score, from, to) {
        if(!from)
            to = -1;
        var cur = score.newCursor();
        cur.track = 0;
        cur.rewind(0);

        var measure = 0;
        while(cur.measure) {
            if(!(from <= measure && measure <= to))
                toggleMeasure(cur.measure, false);
            else
                toggleMeasure(cur.measure, true);
            cur.nextMeasure();
            measure++;
        } 
    }

    /* -- Replay -- */

    Timer {
        id: timer
        function setTimeout(cb, delayTime) {
            timer.interval = delayTime;
            timer.repeat = false;
            timer.triggered.connect(cb);
            timer.triggered.connect(function() {
                timer.triggered.disconnect(cb); // This is important
            });
            timer.start();
        }

        function playMeasures(from, to) {
            if(to < from)
                return;
            var prepareCommands = ["escape", "next-element", "next-measure", "prev-measure"];

            //calculate play time
            var measures = to - from + 1;
            var notesPerMeasure = 4;
            var cur = curScore.newCursor();
            if(cur.timeSignature)
                notesPerMeasure = cur.timeSignature.numerator / cur.timeSignature.denominator * 4;
            var timePerMeasure = notesPerMeasure * 500;
            if(cur.tempo)
                timePerMeasure = (1 / cur.tempo) * notesPerMeasure * 1000;
            var time = timePerMeasure * measures * 0.98;

            for(var c = 0; c < prepareCommands.length; c++)
                cmd(prepareCommands[c]);
            
            for(var i = 0; i < from; i++)
                cmd("next-measure");
            
            cmd("play");

            timer.setTimeout(function(){cmd("play");}, time);
        }
    }

    /*function adjustMeasureLineBreak(score, measuresPerLine) {
        var cur = score.newCursor();
        cur.track = 0;
        cur.rewind(0);

        var i = 0;

        while(cur.measure) {
            if(i % measuresPerLine === 0 && i > 0)
                cur.measure.lineBreak = true;
            else
                cur.measure.lineBreak = false;
            console.log(cur.measure.lineBreak);
            cur.nextMeasure();
            i++;
        }
        
    }*/
    
    function compareMeasures(m1, m2, mapOptions) {
        if(mapOptions && mapOptions.map && mapOptions.m1num && mapOptions.m2num)
            if(mapOptions.map.has(mapOptions.m1num + "-" + mapOptions.m2num))
                return mapOptions.map.get(mapOptions.m1num + "-" + mapOptions.m2num);
        if(m1 === null || m2 === null)
            return false;
        
        var equals = true;
        
        var testSameTick = function(el1, el2) { return el1.tick !== el2.tick; };
        var testSameType = function(el1, el2) { return el1.type !== el2.type; };
        var testRestAndSameDuration = function(el1, el2) {
            return el1.type === Element.REST && testSameType(el1, el2) && el1.durationType !== el2.durationType;
        };

        //CHORDS
        var testSameDuration = function(el1, el2) { return el1.durationType !== el2.durationType; };
        var testSameNumOfNotes = function(el1, el2) { return notes1.length !== notes2.length; };

        //NOTE
        var testSamePitch = function(n1, n2) { return n1.pitch !== n2.pitch; };

        var seg1 = m1.firstSegment;
        var seg2 = m2.firstSegment;
        
        while(seg1 && seg2) {
            var el1 = seg1.elementAt(0);
            var el2 = seg2.elementAt(0);

            if(testSameTick(el1, el2) || testSameType(el1, el2)) {
                equals = false;
                break;
            }
            
            if(testRestAndSameDuration(el1, el2)) {
                equals = false;
                break;
            }
            
            if(el1.type === Element.CHORD) {
                var notes1 = el1.notes;
                var notes2 = el2.notes;

                if(testSameDuration(el1, el2)) {
                    equals = false;
                    break;
                }

                if(testSameNumOfNotes(el1, el2)) {
                    equals = false;
                    break;
                }

                for (var k = 0; k < notes1.length; k++) {
                    if(testSamePitch(notes1[k], notes2[k])) {
                        equals = false;
                        break;
                    }
                }
                
            }

            seg1 = seg1.nextInMeasure;
            seg2 = seg2.nextInMeasure;
        }

        if(seg1 || seg2)
            equals = false;

        if(mapOptions && mapOptions.map && mapOptions.m1num && mapOptions.m2num)
            mapOptions.map.set(mapOptions.m1num + "-" + mapOptions.m2num, equals);

        return equals;
    }

    function getMeasure(score, measure, map) {
        if(map && map.has(measure))
            return map.get(measure);
        if(measure < 0 || measure >= score.nmeasures)
            return null;
        var c1 = score.newCursor();
        c1.track = 0;
        c1.rewind(0);  // set cursor to first chord/rest
        for(var i = 0; i < measure; i++)
            c1.nextMeasure();
        if(map)
            map.set(measure, c1.measure);
        return c1.measure;
    }
    
    function hashMapFactory() {
        var hashmap = { };
        hashmap["_data"] = {};
        hashmap["get"] = function (key) { return this._data[key]; };
        hashmap["set"] = function (key, data) { this._data[key] = data; };
        hashmap["has"] = function (key) { return key in this._data; };
        return hashmap;
    }

    function meyersDiff(s1, s2) {
        var m1Map = hashMapFactory(); // caches measures of s1
        var m2Map = hashMapFactory(); // caches measures of s2
        var mCompMap = hashMapFactory(); // caches comparisons of measures

        var s1length = s1.nmeasures;
        var s2length = s2.nmeasures;
        var maxLength = s1length + s2length;
        var v = new Array(2 * maxLength + 2);
        var x, y, k;
        var trace = [];

        v[1] = 0;
        for(var d = 0; d <= maxLength; d++) {
            //new kpath
            console.log("new kpath: " + d + " => " + v);
            trace[d] = v.slice();
            for(k = -d; k <= d; k += 2) {
                // console.log(k);
                if(k === -d || k !== d && v[k - 1] < v[k + 1]) { // down
                    // console.log("down");
                    x = v[k + 1];
                }
                else { // right
                    // console.log("right");
                    x = v[k - 1] + 1;
                }
                y = x - k;
                // follow snake -> diagonal
                while(x < s1length && y < s2length && 
                  compareMeasures(getMeasure(s1, x, m1Map), getMeasure(s2, y, m2Map), { map: mCompMap, m1num: x, m2num: y })) {
                    // console.log("diagonal");
                    x++;
                    y++;
                }
                // console.log(x + "/" + y);
                v[k] = x;
                if(x >= s1length && y >= s2length) { // reached end
                    // console.log("end: " + v);
                    break;
                }
            }
            if(x >= s1length && y >= s2length) {
                console.log("end: " + v);
                break;
            }
        }

        // reverse traversal
        var path = [];
        x = s1.nmeasures;
        y = s2.nmeasures;
        var prevk, prevx, prevy;
        for(var i = trace.length - 1; i >= 0 ; i--) {
            k = x - y;
            if(k === -i || k !== i && trace[i][k - 1] < trace[i][k + 1])
                prevk = k + 1;
            else
                prevk = k - 1;
            prevx = trace[i][prevk];
            console.log(prevx);
            prevy = prevx - prevk;
            while(x > prevx && y > prevy) {                
                path.push({prevx: x - 1, prevy: y - 1, x: x, y: y});
                x--;
                y--;
            }
            if(i > 0)
                path.push({prevx: prevx, prevy: prevy, x: x, y: y});
            x = prevx;
            y = prevy;
        }

        return path;
    }

    function getEditScript(path, withUpdate) {
        var script = [];
        for(var i = path.length - 1; i >= 0; i--) {
            var step = path[i];
            console.log(step.x + "/" + step.prevx + " " + step.y + "/" + step.prevy)
            if(step.prevy === step.y) {
                if(withUpdate && i >= 1 && path[i-1].prevx === path[i-1].x && step.prevx === path[i-1].prevy) { // next is insertion -> update
                    script.push({action: diffActions.mod, m1: step.prevx, m2: path[i-1].prevy});
                    i--;
                }
                else
                    script.push({action: diffActions.del, m1: step.prevx, m2: null});
            }
            else if(step.prevx === step.x) {
                script.push({action: diffActions.ins, m1: null, m2: step.prevy});
            }
            else
                script.push({action: diffActions.noop, m1: step.prevx, m2: step.prevy});
        }

        return script;
    }

    function printEditScript(script) {
        for(var j = 0; j < script.length; j++) {
            var a = script[j];
            var output = a.action;
            a.m1 = a.m1 || "";
            for(var s = 6 - ("" + a.m1).length; s > 0; s--)
                output += " ";
            if(a.m1)
                output += a.m1;
            output +=  "    |";
            for(var t = 4 - ("" + a.m2).length; t > 0; t--)
                output += " ";
            output += (a.m2 ? a.m2: "");
            console.log(output);
        }
    }

    function applyEditScript(script, s1, s2) {
        script.forEach(function(step) {
            if(step.action !== diffActions.noop) {
                var color;
                if(step.action === diffActions.del)
                    color = colors.red;
                else if(step.action === diffActions.ins)
                    color = colors.green;
                else if(step.action === diffActions.mod)
                    color = colors.blue;
                if(step.m1)
                    colorMeasure(getMeasure(s1, step.m1), color);
                if(step.m2)
                    colorMeasure(getMeasure(s2, step.m2), color);
            }
        });
    }

    function doTheDiff(s1, s2) {
        var c1 = s1.newCursor();
        var c2 = s2.newCursor();

        c1.track = 0;
        c1.rewind(0);  // set cursor to first chord/rest
        c2.track = 0;
        c2.rewind(0);  // set cursor to first chord/rest

        var measure = 0;

        while (c1.measure && c2.measure) {
            var seg1 = c1.measure.firstSegment;
            var seg2 = c2.measure.firstSegment;

            if(!compareMeasures(c1.measure, c2.measure)) {

                while(seg1 || seg2) {
                    if(!seg2) {
                        colorElement(seg1.elementAt(0), colors.red);
                        seg1 = seg1.nextInMeasure;
                        continue;
                    }
                    else if(!seg1) {
                        colorElement(seg2.elementAt(0), colors.green);
                        seg2 = seg2.nextInMeasure;
                        continue;
                    }

                    var el1 = seg1.elementAt(0);
                    var el2 = seg2.elementAt(0);

                    if(seg1.tick < seg2.tick) {
                        if(el1.type === Element.CHORD)
                            colorElement(el1, colors.red);
                        else if(el1.type === Element.REST)
                            colorElement(el1, colors.red);
                        seg1 = seg1.nextInMeasure;
                        continue;
                    }
                    else if(seg1.tick > seg2.tick) {
                        if(el2.type === Element.CHORD)
                            colorElement(el2, colors.green);
                        else if(el2.type === Element.REST)
                            colorElement(el2, colors.green);
                        seg2 = seg2.nextInMeasure;
                        continue;
                    }
                    if(el1.type === Element.CHORD && el2.type === Element.CHORD) {
                        var notes1 = el1.notes;
                        var notes2 = el2.notes;
                        for (var k = 0; k < Math.max(notes1.length, notes2.length); k++)
                        {
                            var note1 = notes1[k];
                            var note2 = notes2[k];
                            if(!note1 && note2)
                                colorElement(note2, colors.green);
                            else if(note1 && !note2)
                                colorElement(note1, colors.red);
                            else { // note1 && note2
                                if(note1.pitch !== note2.pitch) {
                                    colorElement(note1, colors.blue);
                                    colorElement(note2, colors.blue);                                
                                }
                            }
                        }
                    }
                    else if(el1.type === Element.REST && el2.type === Element.REST) {
                        if(el1.durationType !== el2.durationType) {
                            colorElement(el1, colors.blue);
                            colorElement(el2, colors.blue);
                        }
                    }
                    else if(el1.type === Element.REST && el2.type === Element.CHORD) {
                        colorElement(el2, colors.green);
                    }
                    else if(el1.type === Element.CHORD && el2.type === Element.REST) {
                        colorElement(el1, colors.red);
                    }

                    seg1 = seg1.nextInMeasure;
                    seg2 = seg2.nextInMeasure;
                }
            }
            c1.nextMeasure();
            c2.nextMeasure();
            measure++;
        }
    }

    function mergeAndPlayScores(s1, s2, editScript) {

    }

    menuPath: "Plugins.ScoreDiff"
    pluginType: "dialog"
    width:  1400
    height: 1200
    
    ScoreView
    {
        id: scoreview1
        width: 700
        x: 0
        y: 0
        color: "transparent"
    }

    ScoreView
    {
        id: scoreview2
        x: 700
        y: 0
        width: 700
        color: "transparent"
    }

    Button {
        id: btnCompare
        width: 80
        text: qsTr("Compare")
        x: 20
        y: 1020
        onClicked: {
            doTheDiff(score1, score2);
            scoreview1.setScore(score1);
            scoreview2.setScore(score2);
        }
    }

    Button {
        id: btnCompare2
        width: 80
        text: qsTr("Compare2")
        x: 20
        y: 980
        onClicked: {
            var diff = meyersDiff(score1, score2);
            var editScript = getEditScript(diff, true);
            printEditScript(editScript);
            applyEditScript(editScript, score1, score2);
            scoreview1.setScore(score1);
            scoreview2.setScore(score2);
        }
    }

    Button {
        id: btnHide
        width: 80
        text: qsTr("Hide")
        x: 120
        y: 1020
        onClicked: {
            highlightMeasures(score1, null, null);
            scoreview1.setScore(score1);
        }
    }

    Button {
        id: btnShow
        width: 80
        text: qsTr("Show")
        x: 120
        y: 980
        onClicked: {
            highlightMeasures(score1, -1, score1.nmeasures + 1);
            scoreview1.setScore(score1);
        }
    }

    Button {
        id: btnExit
        width: 80
        text: qsTr("Exit")
        x: 220
        y: 1020
        onClicked: {
            score1.endCmd(true);
            score2.endCmd(true);
            resetColors(score1);
            resetColors(score2);
            Qt.quit()
        }
    }

    Button {
        id: btnPrevPage
        width: 20
        text: qsTr("<")
        x: 670
        y: 1020
        onClicked: {
            scoreview1.prevPage();
            scoreview2.prevPage();
        }
    }

    Button {
        id: btnNextPage
        width: 20
        text: qsTr(">")
        x: 710
        y: 1020
        onClicked: {
            scoreview1.nextPage();
            scoreview2.nextPage();
        }
    }

    Button {
        id: btnDifference
        width: 80
        text: qsTr("Difference")
        x: 1000
        y: 940
        onClicked: {
            highlightMeasures(score1, 4, 6);
            highlightMeasures(score2, 4, 6);
            scoreview1.setScore(score1);
            scoreview2.setScore(score2);
        }
    }

    Button {
        id: btnPlayLeft
        width: 80
        text: qsTr("Play Left")
        x: 1000
        y: 980
        onClicked: {
            while(curScore !== score1)
                cmd("previous-score");
            timer.playMeasures(4, 6);
        }
    }

    Button {
        id: btnPlayRight
        width: 80
        text: qsTr("Play Right")
        x: 1000
        y: 1020
        onClicked: {
            while(curScore !== score2)
                cmd("previous-score");
            timer.playMeasures(4, 6);
        }
    }

    onRun:
    {
        if (!curScore) {
            Qt.quit()
            showMessageDialog('The score is not open', 'Open or create a score')
        }
        score1 = scores[0];
        score2 = scores[1];
        score1.startCmd();
        score2.startCmd();
        scoreview1.setScore(score1);
        scoreview2.setScore(score2);
    }
}