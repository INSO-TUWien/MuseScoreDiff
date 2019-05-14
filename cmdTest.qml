import QtQuick 2.0;
import MuseScore 1.1;
import QtQuick.Controls 1.2
import QtQuick.Window 2.2

MuseScore
{
    menuPath: "Plugins.pluginName"
    description: "Description goes here"
    version: "2.0"
    width:  1600
    height: 1200
    
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
            var time = timePerMeasure * measures * 0.95;

            for(var c = 0; c < prepareCommands.length; c++)
                cmd(prepareCommands[c]);
            
            for(var i = 0; i < from; i++)
                cmd("next-measure");
            
            cmd("play");

            timer.setTimeout(function(){cmd("play");}, time);
        }
    }
    
    onRun:
    {
        timer.playMeasures(3, 5);
        // var commands = ["escape", "next-element",
        // "next-measure", "prev-measure", 
        // "next-measure", "next-measure", "next-measure",
        // "play", "play"
        // ];
        // var cur = curScore.newCursor();
        // var measures = 3;
        // var timeSig = 4;
        // if(cur.timeSignature)
        //     timeSig = cur.timeSignature.numerator / cur.timeSignature.denominator * 4;

        // var timing = timeSig * 500;
        // if(cur.tempo)
        //     timing = (1 / cur.tempo) * timeSig * 1000;
        // console.log(timeSig);
        // console.log(timing);
        // console.log(timing * measures);
        // var i = 0;
        // var execute = function() {
        //     cmd(commands[i]);
        //     console.log(commands[i]);
        //     i++;
        //     console.log(i + "/" + commands.length);
        //     if(i < commands.length - 1)
        //         timer.setTimeout(function(){execute();}, 0);
        //     else if(i == commands.length - 1)
        //         timer.setTimeout(function(){execute();}, timing * measures * 0.95);
        // }
        // execute();
    }
}