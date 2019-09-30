import QtQuick 2.0;
import MuseScore 1.1;
import QtQuick.Controls 1.2;
import QtQuick.Window 2.2;

MuseScore
{
    menuPath: "Plugins.ScoreDiff"
    pluginType: "dialog"
    width:  1400
    height: 1200

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

    property int pageNum: 1;

    property bool diffMode: false;
    property var differences;
    property int differenceNum: 0;
    property var leftPlayMeasure: {"start": 0, "end": 0};
    property var rightPlayMeasure: {"start": 0, "end": 0};
    
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
        if(!el)
            return;
        if(!(show === true || show === false))
            show = false;

        if(el.type === Element.CHORD) {
            var notes = el.notes;
            for(var i = 0; i < notes.length; i++)
                toggleElement(notes[i], show);
            toggleElement(el.stem, show);
            toggleElement(el.stemSlash, show);
            toggleElement(el.beam, show);
            toggleElement(el.hook, show);
        }
        else if(el.type === Element.NOTE) {
            el.visible = show;
            toggleElement(el.stem, show);
            toggleElement(el.beam, show);
            toggleElement(el.accidental, show);
            for(var i = 0; i < el.elements; i++)
                toggleElement(el.elements[i], show);
            for(var i = 0; i < el.dots; i++)
                toggleElement(el.dots[i], show);
        }
        else if(el.type === Element.REST)
            el.visible = show;
        else if(el.visible !== null && el.visible !== undefined)
            el.visible = show;
    }

    function colorMeasure(score, measureNum, _color) {
        var measure = getMeasure(score, measureNum);
        if(measureNum > 1) {
            var prevMeasure = getMeasure(score, measureNum - 1);
            colorElement(prevMeasure.lastSegment.elementAt(0), _color, true);
        }
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
            var seg = cur.measure.firstSegment;
            while(seg) {
                colorElement(seg.elementAt(0), colors.black, true);
                seg = seg.nextInMeasure;
            }
            toggleMeasure(cur.measure, true);
            cur.nextMeasure();
        }
    }

    function highlightMeasures(score, from, to) {
        if(!from && !from === 0)
            to = -1;
        var cur = score.newCursor();
        cur.track = 0;
        cur.rewind(0);


        var measure = 0;
        while(cur.measure) {
            if(from <= measure && measure <= to)
                toggleMeasure(cur.measure, true);
            else
                toggleMeasure(cur.measure, false);
            cur.nextMeasure();
            measure++;
        } 
    }

    function clearHighlighting(score) {
        var cur = score.newCursor();
        cur.track = 0;
        cur.rewind(0);

        while(cur.measure) {
            toggleMeasure(cur.measure, true);
            cur.nextMeasure();
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

        function playMeasures(from, to, supressStop) {
            if (supressStop !== true)
                supressStop = false;
            if (to < from)
                return;

            var prepareCommands = ["escape", "next-element", "next-measure", "prev-measure"];            
            for (var c = 0; c < prepareCommands.length; c++)
                cmd(prepareCommands[c]);

            // Disable play buttons until playback is finished
            btnPlayLeft.enabled = false;
            btnPlayRight.enabled = false;

            //calculate play time
            var measures = to - from + 1;
            var notesPerMeasure = 4;
            var cur = curScore.newCursor();
            if (cur.timeSignature)
                notesPerMeasure = cur.timeSignature.numerator / cur.timeSignature.denominator * 4;
            var timePerMeasure = notesPerMeasure * 500;
            if (cur.tempo)
                timePerMeasure = notesPerMeasure / cur.tempo * 1000;
            var time = timePerMeasure * measures * 0.98;

            for (var i = 0; i < from; i++) {
                cmd("next-measure");
            }
            cmd("play");
            timer.setTimeout(function() {
                cmd("play");
            }, time);
        }
    }
    
    function compareMeasures(m1, m2) {
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

        return equals;
    }

    function getMeasureCursor(score, measure) {
        measure--;
        if(measure < 0 || measure >= score.nmeasures)
            return null;
        var c = score.newCursor();
        c.track = 0;
        c.rewind(0);  // set cursor to first chord/rest
        for(var i = 0; i < measure; i++)
            c.nextMeasure();

        return c;

    }

    function getMeasure(score, measure) {
        measure--;
        if(measure < 0 || measure >= score.nmeasures)
            return null;
        var c = score.newCursor();
        c.track = 0;
        c.rewind(0);  // set cursor to first chord/rest
        for(var i = 0; i < measure; i++)
            c.nextMeasure();
        return c.measure;
    }

    function lcsLength(s1, s2) {
        var s1length = s1.nmeasures;
        var s2length = s2.nmeasures;

        var c = new Array(s1length + 1);

        for(var i = 0; i <= s1length; i++)
            c[i] = new Array(s2length + 1);
        for(var i = 0; i <= s1length; i++)
            c[i][0] = 0;
        for(var i = 0; i <= s2length; i++)
            c[0][i] = 0;
        
        for(var i = 1; i <= s1length; i++) {
            for(var j = 1; j <= s2length; j++) {
                if(compareMeasures(getMeasure(s1, i), getMeasure(s2, j)))
                    c[i][j] = c[i - 1][j - 1] + 1;
                else
                    c[i][j] = Math.max(c[i][j - 1], c[i - 1][j]);
            }
        }
        
        return c;
    }

    function getEditScript(c, s1, s2, i, j) {
        var script = [];
        if(i > 0 && j > 0 && compareMeasures(getMeasure(s1, i), getMeasure(s2, j))) {
            script = getEditScript(c, s1, s2, i - 1, j - 1);
            script.push({action: diffActions.noop, m1: i, m2: j});
        }
        else if(j > 0 && (i === 0 || c[i][j - 1] >= c[i - 1][j])) {
            script = getEditScript(c, s1, s2, i, j - 1);
            script.push({action: diffActions.ins, m1: null, m2: j});
        }
        else if(i > 0 && (j === 0 || c[i][j - 1] < c[i - 1][j])) {
            script = getEditScript(c, s1, s2, i - 1, j);
            script.push({action: diffActions.del, m1: i, m2: null});
        }
        
        return script;
    }

    function applyEditScript(script, s1, s2) {
        script.forEach(function(step) {
            if(step.action === diffActions.mod) {
                diffMeasure(s1, s2, step.m1, step.m2)
            }
            else {
                var color;
                if(step.action === diffActions.del)
                    color = colors.red;
                else if(step.action === diffActions.ins)
                    color = colors.green;
                if(step.m1)
                    colorMeasure(s1, step.m1, color);
                if(step.m2)
                    colorMeasure(s2, step.m2, color);
            }
        });
    }

    // Merges consecutive inserts and deletes into a single modify action
    // Also removes noop actions
    function consolidateScript(script) {
        var newScript = [];
        for(var i = 0; i < script.length - 1; i++) {
            if(script[i].action === diffActions.del && script[i + 1].action === diffActions.ins) {
                newScript.push({action: diffActions.mod, m1: script[i].m1, m2: script[i + 1].m2});
                i++;
            }
            else if(script[i].action !== diffActions.noop)
                newScript.push(script[i]);
        }

        return newScript;
    }

    // Diffs and colors two measures
    function diffMeasure(s1, s2, measure1, measure2) {
        var c1 = getMeasureCursor(s1, measure1);
        var c2 = getMeasureCursor(s2, measure2);
        
        var seg1 = c1.measure.firstSegment;
        var seg2 = c2.measure.firstSegment;

        var seg1Offset = seg1.tick;
        var seg2Offset = seg2.tick;

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
            
            if((seg1.tick - seg1Offset) < (seg2.tick - seg2Offset)) {
                colorElement(el1, colors.red);
                seg1 = seg1.nextInMeasure;
                continue;
            }
            else if((seg1.tick - seg1Offset) > (seg2.tick - seg2Offset)) {
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

    function diff(score1, score2) {
        var lcs = lcsLength(score1, score2);
        var script = getEditScript(lcs,score1, score2, 
            score1.nmeasures, score2.nmeasures);

        script = consolidateScript(script);
        
        applyEditScript(script, score1, score2);

        differences = script;
    }

    function applyDiffNum() {
        var difference = differences[differenceNum - 1];
        var m1 = difference.m1;
        var m2 = difference.m2;

        if(!m1)
            m1 = m2;
        if(!m2)
            m2 = m1;
        
        var s1Start = Math.max(0, m1 - 2);
        var s2Start = Math.max(0, m2 - 2);

        var s1End = Math.min(score1.nmeasures, m1);
        var s2End = Math.min(score2.nmeasures, m2);

        if(s1Start < score1.nmeasures)
            highlightMeasures(score1, s1Start, s1End);
        if(s1Start < score1.nmeasures)
            highlightMeasures(score2, s2Start, s2End);

        leftPlayMeasure = {start: s1Start, end: s1End};
        rightPlayMeasure = {start: s2Start, end: s2End};
        
        scoreview1.setScore(score1);
        scoreview2.setScore(score2);
    }

    function onNextDifferenceClick() {
        if(differenceNum < differences.length)
            differenceNum++;
        if(differenceNum > 1)
            btnPrevDifference.enabled = true;
        if(differenceNum === differences.length)
            btnNextDifference.enabled = false;

        applyDiffNum();
    }

    Button {
        id: btnToggleDiffMode
        width: 200
        text: diffMode ? "Disable Diff Mode" : "Enable Diff Mode"
        x: 100
        y: 20
        onClicked: {
            if(!diffMode) {
                btnNextDifference.enabled = true;
                btnPlayLeft.enabled = true;
                btnPlayRight.enabled = true;
                onNextDifferenceClick();
            }
            else {
                clearHighlighting(score1);
                clearHighlighting(score2);
                scoreview1.setScore(score1);
                scoreview2.setScore(score2);

                btnPrevDifference.enabled = false;
                btnNextDifference.enabled = false;
                btnPlayLeft.enabled = false;
                btnPlayRight.enabled = false;
                differenceNum = 0;
            }
            diffMode = !diffMode;
        }
    }

    Button {
        id: btnPrevDifference
        width: 20
        text: qsTr("<")
        enabled: false
        x: 620
        y: 20
        onClicked: {
            if(differenceNum > 1)
                differenceNum--;
            if(differenceNum == 1)
                btnPrevDifference.enabled = false;
            if(differenceNum < differences.length)
                btnNextDifference.enabled = true;
                
            applyDiffNum();
        }
    }

    Text {
      id: lblDifference
      text: "Difference " + differenceNum + " / " + (differences ? differences.length : 0)
      x: 650
      y: 25
    }

    Button {
        id: btnNextDifference
        width: 20
        text: qsTr(">")
        enabled: false
        x: 760
        y: 20
        onClicked: onNextDifferenceClick()
    }

    Button {
        id: btnPlayLeft
        width: 80
        text: qsTr("Play")
        enabled: false
        x: 300
        y: 20
        onClicked: {
            while (curScore !== score1) {
                cmd("previous-score");
            }

            var supressStop = leftPlayMeasure.end === score1.nmeasures - 1;
            timer.playMeasures(leftPlayMeasure.start, leftPlayMeasure.end, supressStop);
        }
    }

    Button {
        id: btnPlayRight
        width: 80
        text: qsTr("Play")
        enabled: false
        x: 1000
        y: 20
        onClicked: {
            while (curScore !== score2) {
                cmd("previous-score");
            }

            var supressStop = rightPlayMeasure.end === score2.nmeasures - 1;
            timer.playMeasures(rightPlayMeasure.start, rightPlayMeasure.end, supressStop);
        }
    }
    
    ScoreView {
        id: scoreview1
        width: 700
        x: 0
        y: 45
        color: "transparent"
    }

    ScoreView {
        id: scoreview2
        x: 700
        y: 45
        width: 700
        color: "transparent"
    }

    Button {
        id: btnExit
        width: 80
        text: qsTr("Exit")
        x: 1240
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
        enabled: false
        text: qsTr("<")
        x: 650
        y: 1020
        onClicked: {
            btnNextPage.enabled = true;
            scoreview1.prevPage();
            scoreview2.prevPage();

            if(pageNum > 1)
                pageNum--;
            if(pageNum === 1)
                btnPrevPage.enabled = false;

        }
    }
    
    Text {
      id: lblPage
      text: "Page " + pageNum
      x: 680
      y: 1025
    }

    Button {
        id: btnNextPage
        width: 20
        text: qsTr(">")
        x: 730
        y: 1020
        onClicked: {
            btnPrevPage.enabled = true;
            scoreview1.nextPage();
            scoreview2.nextPage();

            if(pageNum < Math.max(score1.npages, score2.npages))
                pageNum++;
            if(pageNum === Math.max(score1.npages, score2.npages))
                btnNextPage.enabled = false;
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
        diff(score1, score2);
        scoreview1.setScore(score1);
        scoreview2.setScore(score2);

        if(Math.max(score1.npages, score2.npages) === 1)
            btnNextPage.enabled = false;
    }
}
