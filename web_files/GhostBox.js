"use strict";


function GhostBox() {
    this.options = null;
    this.lastSignalId = -1;  // Unique incrementing id of the last signal history entry
    this.noiseButtons = [];  // List of noise toggle buttons
    this.pendingChanges = 0; // Counter of changes not yet sent to the server
    this.errorMessage = '';  // Last error encountered to display
    this.sleepTime = 50;     // Real sleep time from server, set so the UI changes don't override

    this.initUI();
}


/********************************************************************************
 * Initialization
 ********************************************************************************/

GhostBox.prototype.initUI = function() {
    var self = this;

    this.ui = {
        'demodulatorMode':  document.getElementById('demodulator-mode'),
        'minFrequency': document.getElementById('min-frequency'),
        'maxFrequency': document.getElementById('max-frequency'),
        'scanningMode': document.getElementById('scanning-mode'),
        'scanningStep': document.getElementById('scanning-step'),
        'sleepTime': document.getElementById('sleep-time'),

        'whiteNoise': document.getElementById('white-noise'),
        'whiteNoiseVolume': document.getElementById('white-noise-volume'),
        'pinkNoise': document.getElementById('pink-noise'),
        'pinkNoiseVolume': document.getElementById('pink-noise-volume'),
        'brownNoise': document.getElementById('brown-noise'),
        'brownNoiseVolume': document.getElementById('brown-noise-volume'),

        'resetButton': document.getElementById('reset-button'),
        'updateButton': document.getElementById('update-button'),
    };

    this.setDisabledUI(true);
    this.initDisplayCanvas();
    this.initNoiseControls();

    this.ui['resetButton'].addEventListener('click', function() {
        self.resetOptions();
    });
    this.ui['updateButton'].addEventListener('click', function() {
        self.submitOptions();
    });

    this.makeRequest({
        uri: '/options',
        onComplete: function(request) {
            var options = JSON.parse(request.responseText);
            self.options = options;

            self.setDisabledUI(false);
            self.initUIChangeEvents();
            self.updateInputs();
            self.updateDisplayCanvas();
        },
        onError: function() {
            self.errorMessage = 'ERROR: Server communication failed';
        }
    });
};


/********************************************************************************
 * Controls
 ********************************************************************************/

GhostBox.prototype.initNoiseControls__initControl = function(name) {
    var button = this.ui[name];
    var self = this;
    var noiseGenerator;
    var audioContext = new AudioContext();
    var gainNode = audioContext.createGain();
    var volumeRange = this.ui[name + 'Volume'];
    var x;

    if (name == 'whiteNoise')      { noiseGenerator = audioContext.createWhiteNoise(); }
    else if (name == 'pinkNoise')  { noiseGenerator = audioContext.createPinkNoise(); }
    else if (name == 'brownNoise') { noiseGenerator = audioContext.createBrownNoise(); }

    gainNode.connect(audioContext.destination);

    button.addEventListener('click', function() {
        if (button.className.match('pressed')) {
            button.className = '';

            noiseGenerator.disconnect();
        }
        else {
            button.className = 'pressed';

            noiseGenerator.connect(gainNode);
        }

        if (! button.className.match('pending')) {
            button.className += ' pending';
            self.pendingChanges++;
        }
    });

    volumeRange.addEventListener('change', function() {
        gainNode.gain.value = volumeRange.value;

        if (! button.className.match('pending')) {
            button.className += ' pending';
            self.pendingChanges++;
        }
    });
};


GhostBox.prototype.initNoiseControls = function() {
    var buttons = ['whiteNoise', 'pinkNoise', 'brownNoise'];
    var x = 0;
    var button;

    this.noiseButons = [];

    for (x = 0; x < buttons.length; x++) {
        this.initNoiseControls__initControl(buttons[x]);

        this.noiseButtons.push(this.ui[buttons[x]]);
    }
};


GhostBox.prototype.updateButtonState = function(button, isPressed) {
    var isCurrentlyPressed = button.className == 'presed' ? true : false;

    if (isPressed != isCurrentlyPressed) {
        // If the requested state differs from the current state, click the button
        button.dispatchEvent(new Event('click'));
    }

    console.log("1: B=%O, C=%O",button,button.className);
    button.className = button.className.replace(/\s?pending/, '');
    console.log("2: B=%O, C=%O",button,button.className);
};


GhostBox.prototype.updateInputs = function() {
    // Update the inputs from the options
    var name;
    var element;
    var elementType;

    for (name in this.options) {
        element = this.ui[name];

        if (element) {
            elementType = element.type;

            if (elementType == 'submit') {
                this.updateButtonState(element, this.options[name]);
            }
            else if (elementType.match(/^select/)) {
                element.className = ''; // Reset any 'pending' class
                element.value = this.options[name];
            }
            else {
                element.className = ''; // Reset any 'pending' class
                element.value = this.options[name];
            }
        }
    }

    // Reset any pending changes
    this.pendingChanges = 0;
    this.ui['updateButton'].className = '';

    // Update the sleepTime to the real server time
    this.sleepTime = this.options['sleepTime'];
};


GhostBox.prototype.setDisabledUI = function(state) {
    var name;

    for (name in this.ui) {
        this.ui[name].disabled = state;
    }
};


GhostBox.prototype.initUIChangeEvents = function() {
    // Set up the change events for the UI elements
    var inputs = ['demodulatorMode', 'minFrequency', 'maxFrequency', 'scanningMode',
                  'scanningStep', 'sleepTime']
    var self = this;
    var x;

    function addEventHandler(name) {
        self.ui[name].addEventListener('change', function() {
            var element = self.ui[name];

            if (element.className.match('pending')) {
                if (element.value == self.options[name]) {
                    element.className = '';
                    self.pendingChanges--;

                    if (self.pendingChanges == 0) {
                        self.ui.updateButton.className =
                            self.ui.updateButton.className.replace(/\s?pending/, '');
                    }
                }
            }
            else {
                element.className = 'pending';
                self.pendingChanges++;
                self.ui.updateButton.className = 'pending';
            }

            self.options[name] = element.value;
        });
    }

    for (x = 0; x < inputs.length; x++) {
        addEventHandler(inputs[x]);
    }
};


GhostBox.prototype.resetOptions = function() {
    var self = this;

    this.setDisabledUI(true);

    this.makeRequest({
        uri: '/options',
        onComplete: function(request) {
            var options = JSON.parse(request.responseText);
            self.options = options;

            self.setDisabledUI(false);
            self.updateInputs();
        },
        onError: function() {
            self.errorMessage = 'ERROR; Failed to revert options';
            self.setDisabledUI(false);
        }
    });
};


GhostBox.prototype.submitOptions = function() {
    var self = this;
    var x;

    this.setDisabledUI(true);

    this.makeRequest({
        uri: '/options',
        type: 'POST',
        contentType: 'application/json',
        payload: JSON.stringify(this.options),
        onComplete: function(request) {
            self.updateInputs();
            self.setDisabledUI(false);

            self.errorMessage = '';
        },
        onError: function(request) {
            var errors = JSON.parse(request.responseText);

            if (errors.length) {
                self.errorMessage = errors[0].message;

                for (x = 0; x < errors.length; x++) {
                    self.ui[errors[x].camelKey].className = 'error';
                }
            }

            self.setDisabledUI(false);
        }
    });
};


/********************************************************************************
 * Display
 ********************************************************************************/

GhostBox.prototype.initDisplayCanvas = function() {
    // The display itself
    this.displayCanvas = document.getElementById("display");
    this.displayContext = this.displayCanvas.getContext('2d');

    // The fading display buffer
    this.bufferCanvas = document.createElement('canvas');
    this.bufferContext = this.bufferCanvas.getContext('2d');
    this.bufferCanvas.width = this.displayCanvas.width;
    this.bufferCanvas.height = this.displayCanvas.height;

    this.displayContext.fillStyle = '#2db300';
    this.displayContext.fillStyle = '#1f8ad2';
    this.displayContext.fillRect(0, 0, this.displayCanvas.width, this.displayCanvas.height);

    this.lastDisplayCanvasUpdateRequest = Date.now();
    this.displayCanvasUpdateRequestInProgress = false;
};


GhostBox.prototype.updateBufferCanvas = function(state) {
    // Update the bufferCanvas, which stores a the drawn bars and
    // makes them slowly fade over time
    var context = this.bufferContext;
    var canvasWidth = this.displayCanvas.width;
    var canvasHeight = this.displayCanvas.height;
    var tmpCanvas = document.createElement('canvas');
    var tmpContext = tmpCanvas.getContext('2d');
    var options = this.options;
    var imageData;
    var strengthPoint;
    var x;
    var xPos;
    var yPos;

    // Fade the bufferContext;
    //   Write the current pixels to the tmp canvas
    tmpCanvas.width = canvasWidth;
    tmpCanvas.height = canvasHeight;
    tmpContext.drawImage(this.bufferCanvas, 0, 0);
    //   Clear the current buffer and write back the original with lower alpha
    context.clearRect(0, 0, canvasWidth, canvasHeight);
    context.globalAlpha = 0.99;
    context.drawImage(tmpCanvas, 0, 0);

    for (x = state['signalStrengthHistory'].length - 1; x >= 0; x--) {
        strengthPoint = state['signalStrengthHistory'][x];

        if (strengthPoint['id'] < this.lastSignalId) {
            continue;
        }

        this.lastSignalId = strengthPoint['id'];

        xPos = Math.round(((strengthPoint['frequency'] - options['minFrequency']) /
                           (options['maxFrequency'] - options['minFrequency'])) * canvasWidth);
        yPos = Math.round(21 + (strengthPoint['strength'] * -1 / 50) * (canvasHeight - 21));

        // Draw the bar
        context.globalAlpha = 0.1;
        context.fillRect(xPos, yPos, 3, canvasHeight - yPos);

        // Draw the current peak
        context.globalAlpha = 1.0;
        context.fillRect(xPos, yPos, 3, 1);

        this.displayContext.fillStyle = '#FF0000';
        this.displayContext.fillRect(xPos, yPos - 1, 3, 3);
        this.displayContext.fillStyle = '#000000';
    }
};


GhostBox.prototype.drawDisplayCanvas = function(state) {
    var displayCanvas = this.displayCanvas;
    var displayContext = this.displayContext;
    var options = this.options;

    // Write the current frequency
    displayContext.font = '20px Arial';
    displayContext.fillStyle = '#1f8ad2';
    displayContext.fillRect(0, 0, displayCanvas.width, displayCanvas.height);
    displayContext.fillStyle = '#000000';
    displayContext.fillText(state['currentFrequency'] + ' Khz', 3, 20);

    // Write any error messages
    displayContext.font = '12px Arial';
    displayContext.fillStyle = '#811b23';
    displayContext.fillText(this.errorMessage, 3,
                            displayCanvas.height - 10, displayCanvas.width - 6);


    this.updateBufferCanvas(state);
    displayContext.drawImage(this.bufferCanvas, 0, 0);

    // Draw a red bar to show the current frequency
    displayContext.save();
    displayContext.fillStyle = '#ff0000';
    displayContext.globalAlpha = 0.2;
    displayContext.fillRect(((state['currentFrequency'] - options['minFrequency']) /
                             (options['maxFrequency'] - options['minFrequency'])) * displayCanvas.width,
                            0,
                            3,
                            displayCanvas.height);
    displayContext.restore();
};


GhostBox.prototype.updateDisplayCanvas = function() {
    var self = this;
    var timeToNextUpdate;

    timeToNextUpdate = Date.now() - this.lastDisplayCanvasUpdateRequest -
        Math.max(this.sleepTime, 500);

    if (timeToNextUpdate >= 0) {
        this.lastDisplayCanvasUpdateRequest = Date.now();

        this.makeRequest({
            uri: '/status',
            onComplete: function(request) {
                var state = JSON.parse(request.responseText);

                self.drawDisplayCanvas(state); // Draw the current state
                self.updateDisplayCanvas();    // Schedule the next update
            },
            onError: function() {
                self.errorMessage = 'ERROR: Server communication failed';
            }
        });
    }
    else {
        setTimeout(function() {
            self.updateDisplayCanvas();
        }, timeToNextUpdate);
    }
};


/********************************************************************************
 * Utility
 ********************************************************************************/

GhostBox.prototype.makeRequest = function(args) {
    var r = new XMLHttpRequest();

    args.type = args.type || 'GET';
    args.uri = args.uri || '';

    if (args.type == "GET" && args.data) {
        args.uri += '?' + args.data;
    }

    r.onreadystatechange = function() {
        if (r.readyState != 4)    { return; }
        else if (r.status == 200) { args.onComplete && args.onComplete(r); }
        else                      { args.onError && args.onError(r); }
    };

    r.open(args.type, args.uri, true);

    if (args.responseType) {
        r.responseType = args.responseType;
    }

    if (args.type == "POST" || args.contentType) {
        r.setRequestHeader('Content-Type', args.contentType || 'application/x-www-form-urlencoded');
    }

    r.send(args.payload);

    return (r);
};


/********************************************************************************/

var gb; // DEBUG
window.addEventListener('load', function() {
    gb = new GhostBox();
});
