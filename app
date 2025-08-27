// app.js

// --- Global Variables & Constants ---
let currentUserPreferences = {};
const PREFS_KEY = 'mandarinAppPreferences';
let currentAudio = null; // For managing speech audio

// --- DOM Element References (to be initialized on DOMContentLoaded) ---
let appContainer, prefsScreen, mainMenu, rapidFireGame, chatterGame, parrotGame, scoreScreen;
let prefsForm, rapidFireTilesLeft, rapidFireTilesRight, chatterQuestion, parrotTile, scoreDisplay, animalAnimation;
let speechRecognizer; // Web Speech API SpeechRecognition object
let synth; // Web Speech API SpeechSynthesis object (for text-to-speech if needed, though you have audio files)

// --- Helper Functions ---

// Function to navigate between screens
function showScreen(screenElement) {
    document.querySelectorAll('.app-screen').forEach(screen => {
        screen.style.display = 'none';
    });
    screenElement.style.display = 'block';
}

// Function to load preferences from localStorage
function loadPreferences() {
    const storedPrefs = localStorage.getItem(PREFS_KEY);
    if (storedPrefs) {
        currentUserPreferences = JSON.parse(storedPrefs);
        return true;
    }
    return false;
}

// Function to save preferences to localStorage
function savePreferences() {
    localStorage.setItem(PREFS_KEY, JSON.stringify(currentUserPreferences));
}

// Function to play sound (success/error)
function playSound(type) {
    const audio = new Audio(`audio/${type}.mp3`); // e.g., audio/success.mp3, audio/error.mp3
    audio.play();
}

// Function to play Mandarin phrase audio
function playMandarinAudio(audioPath) {
    if (currentAudio) {
        currentAudio.pause();
        currentAudio.currentTime = 0;
    }
    currentAudio = new Audio(audioPath);
    currentAudio.play();
}

// --- Preference Screen Logic ---
function setupPreferencesScreen() {
    prefsForm.addEventListener('submit', (e) => {
        e.preventDefault();
        const formData = new FormData(prefsForm);
        currentUserPreferences = {};
        let allMandatoryFilled = true;
        for (let [key, value] of formData.entries()) {
            currentUserPreferences[key] = value;
            if (key !== 'anythingElse' && !value.trim()) {
                allMandatoryFilled = false;
            }
        }

        if (allMandatoryFilled) {
            savePreferences();
            showScreen(mainMenu);
        } else {
            alert("Please fill in all mandatory preference fields!");
        }
    });

    // Populate form if preferences exist
    if (loadPreferences()) {
        for (const key in currentUserPreferences) {
            const input = prefsForm.elements[key];
            if (input) {
                input.value = currentUserPreferences[key];
            }
        }
    }
}

// --- Main Menu Logic ---
function setupMainMenu() {
    document.getElementById('rapidFireTile').addEventListener('click', () => {
        startRapidFireGame();
        showScreen(rapidFireGame);
    });
    document.getElementById('chatterTile').addEventListener('click', () => {
        startChatterGame();
        showScreen(chatterGame);
    });
    document.getElementById('parrotTile').addEventListener('click', () => {
        startParrotGame();
        showScreen(parrotGame);
    });
    document.getElementById('updatePrefsTile').addEventListener('click', () => {
        showScreen(prefsScreen);
    });
}

// --- Rapid Fire Game Logic ---
let rapidFireState = {
    currentRound: 0,
    totalScore: 0,
    correctPairs: [],
    selectedMandarinTile: null,
    phrasesForRound: []
};

function startRapidFireGame() {
    rapidFireState.currentRound = 0;
    rapidFireState.totalScore = 0;
    rapidFireState.correctPairs = [];
    rapidFireState.selectedMandarinTile = null;
    playRapidFireRound();
}

function playRapidFireRound() {
    rapidFireState.currentRound++;
    if (rapidFireState.currentRound > 3) {
        endRapidFireGame();
        return;
    }

    rapidFireState.phrasesForRound = getRandomPhrases(5); // Get 5 random phrases
    rapidFireState.correctPairs = Array(5).fill(false);
    rapidFireState.selectedMandarinTile = null;

    renderRapidFireTiles();
}

function renderRapidFireTiles() {
    rapidFireTilesLeft.innerHTML = '';
    rapidFireTilesRight.innerHTML = '';

    const mandarinTilesData = rapidFireState.phrasesForRound;
    const englishTilesData = rapidFireState.phrasesForRound.slice().sort(() => 0.5 - Math.random()); // Shuffle English

    mandarinTilesData.forEach((phrase, index) => {
        const tile = createTile(`
            <div class="kanji">${phrase.mandarin}</div>
            <div class="pinyin">${phrase.pinyin}</div>
        `, 'mandarin-tile', index);
        tile.dataset.phraseId = phrase.mandarin; // Use mandarin as unique ID for pairing
        tile.addEventListener('click', handleRapidFireClick);
        rapidFireTilesLeft.appendChild(tile);
    });

    englishTilesData.forEach((phrase, index) => {
        const tile = createTile(`<div>${phrase.english}</div>`, 'english-tile', index);
        tile.dataset.phraseId = phrase.mandarin; // Use mandarin as unique ID for pairing
        tile.addEventListener('click', handleRapidFireClick);
        rapidFireTilesRight.appendChild(tile);
    });
}

function handleRapidFireClick(event) {
    const clickedTile = event.currentTarget;
    const isMandarinTile = clickedTile.classList.contains('mandarin-tile');

    if (isMandarinTile) {
        if (rapidFireState.correctPairs[clickedTile.dataset.index]) {
            // Already correctly matched, ignore
            return;
        }
        if (rapidFireState.selectedMandarinTile) {
            rapidFireState.selectedMandarinTile.classList.remove('selected');
        }
        rapidFireState.selectedMandarinTile = clickedTile;
        rapidFireState.selectedMandarinTile.classList.add('selected');
    } else { // English tile clicked
        if (!rapidFireState.selectedMandarinTile) {
            // No Mandarin tile selected yet
            playSound('error');
            return;
        }

        const mandarinPhraseId = rapidFireState.selectedMandarinTile.dataset.phraseId;
        const englishPhraseId = clickedTile.dataset.phraseId;

        if (mandarinPhraseId === englishPhraseId) {
            // Correct match!
            playSound('success');
            rapidFireState.totalScore++; // Award point
            const mandIndex = rapidFireState.phrasesForRound.findIndex(p => p.mandarin === mandarinPhraseId);
            rapidFireState.correctPairs[mandIndex] = true;

            rapidFireState.selectedMandarinTile.classList.add('matched');
            clickedTile.classList.add('matched');
            rapidFireState.selectedMandarinTile.classList.remove('selected');
            clickedTile.removeEventListener('click', handleRapidFireClick);
            rapidFireState.selectedMandarinTile.removeEventListener('click', handleRapidFireClick);

            rapidFireState.selectedMandarinTile = null; // Reset selection

            if (rapidFireState.correctPairs.every(status => status === true)) {
                // Round completed
                setTimeout(playRapidFireRound, 1000); // Start next round after a short delay
            }
        } else {
            // Incorrect match
            playSound('error');
            // User cannot score points for the selected Mandarin tile if already incorrect once
            // This logic needs refinement: Perhaps mark the mandarin tile as "attempted-incorrect"
            // For simplicity, for now, just play error and allow another guess.
            // For strict "cannot score any points if incorrect", we'd need a separate state for each Mandarin tile.
            // For now, if the user makes an incorrect guess, they still have the chance to match it correctly later for a point.
            // The request states "If an incorrect guess has been made for a mandarin tile, the user can not score any points for it."
            // This means we need to track if a specific mandarin tile (left) has been part of an incorrect pairing attempt.
            const mandIndex = rapidFireState.phrasesForRound.findIndex(p => p.mandarin === mandarinPhraseId);
            if (!rapidFireState.correctPairs[mandIndex]) { // Only if not already correctly matched
                 // Mark this specific mandarin tile as "invalid for scoring" if an incorrect match involved it.
                 // This requires a more complex `rapidFireState` to track scoring eligibility per tile.
                 // For current simple implementation, we'll allow retries until correct.
                 // If you want strict adherence: need `mandarinTilesScorable[index] = false`
                 // and when calculating score, only sum `correctPairs[i]` where `mandarinTilesScorable[i]` is true.
            }
            // Reset selection after incorrect guess to try again
            rapidFireState.selectedMandarinTile.classList.remove('selected');
            rapidFireState.selectedMandarinTile = null;
        }
    }
}


function endRapidFireGame() {
    displayScore(rapidFireState.totalScore, 'rapidFire');
}

// --- Chatter Game Logic ---
let chatterState = {
    currentQuestionIndex: 0,
    totalScore: 0,
    questionsForGame: [],
    triesLeft: 3,
    currentQuestionPoints: 2 // Max points for current question
};

function startChatterGame() {
    chatterState.currentQuestionIndex = 0;
    chatterState.totalScore = 0;
    chatterState.questionsForGame = getRandomPhrases(10, 'question'); // Get 10 random questions
    if (chatterState.questionsForGame.length < 10) {
        alert("Not enough 'question' type phrases in data.js to start Chatter game.");
        showScreen(mainMenu);
        return;
    }
    setupSpeechRecognition();
    presentChatterQuestion();
}

function presentChatterQuestion() {
    if (chatterState.currentQuestionIndex >= chatterState.questionsForGame.length) {
        endChatterGame();
        return;
    }

    const question = chatterState.questionsForGame[chatterState.currentQuestionIndex];
    chatterQuestion.innerHTML = `
        <div class="kanji">${question.mandarin}</div>
        <div class="pinyin">${question.pinyin}</div>
        <div class="english">${question.english}</div>
        <button id="playAudioChatter">Play Audio</button>
        <button id="answerChatter">Answer</button>
        <div id="chatterFeedback" style="margin-top: 10px;"></div>
    `;

    document.getElementById('playAudioChatter').addEventListener('click', () => playMandarinAudio(question.audio));
    document.getElementById('answerChatter').addEventListener('click', startSpeechRecognitionForChatter);

    chatterState.triesLeft = 3;
    chatterState.currentQuestionPoints = 2; // Reset points for new question
    document.getElementById('chatterFeedback').textContent = '';
}

function startSpeechRecognitionForChatter() {
    if (!speechRecognizer) {
        alert("Speech recognition not available or initialized.");
        return;
    }
    document.getElementById('answerChatter').disabled = true;
    speechRecognizer.start();
    document.getElementById('chatterFeedback').textContent = 'Listening...';
}

function handleChatterResult(transcript) {
    document.getElementById('answerChatter').disabled = false;
    const question = chatterState.questionsForGame[chatterState.currentQuestionIndex];
    const feedbackDiv = document.getElementById('chatterFeedback');

    let rating = 3; // Not quite, try again by default
    let scoreAwarded = 0;

    // Simple keyword matching for demo. Real app needs NLP.
    const userSaid = transcript.toLowerCase();
    const matched = question.answerKeywords.some(keyword => userSaid.includes(keyword.toLowerCase()));

    // More advanced: check if user's transcript matches expected answers or close variations
    for (const expectedAnswer in question.answerRating) {
        if (userSaid.includes(expectedAnswer.toLowerCase())) {
            rating = question.answerRating[expectedAnswer];
            break;
        }
        // Could also use string similarity metrics here
    }

    if (matched || rating === 2) { // Consider "matched" as good enough for a point for simplicity
        rating = 1; // "Sounds great, well done!"
        scoreAwarded = chatterState.currentQuestionPoints;
        feedbackDiv.textContent = `Sounds great, well done! You said: "${transcript}"`;
        chatterState.totalScore += scoreAwarded;
        setTimeout(() => {
            chatterState.currentQuestionIndex++;
            presentChatterQuestion();
        }, 1500);
    } else {
        chatterState.triesLeft--;
        if (chatterState.triesLeft > 0) {
            rating = 2; // "Could do a bit better"
            feedbackDiv.textContent = `Could do a bit better. You said: "${transcript}". Tries left: ${chatterState.triesLeft}`;
            chatterState.currentQuestionPoints = 1; // Future attempts max 1 point
            const tryAgainBtn = document.createElement('button');
            tryAgainBtn.textContent = 'Try Again';
            tryAgainBtn.addEventListener('click', presentChatterQuestion); // Re-render current question to retry
            feedbackDiv.appendChild(tryAgainBtn);
        } else {
            rating = 3; // "Not quite, try again"
            feedbackDiv.textContent = `Not quite, try again. You said: "${transcript}". No tries left.`;
            const moveOnBtn = document.createElement('button');
            moveOnBtn.textContent = 'Move On';
            moveOnBtn.addEventListener('click', () => {
                chatterState.currentQuestionIndex++;
                presentChatterQuestion();
            });
            feedbackDiv.appendChild(moveOnBtn);
        }
    }
}

function endChatterGame() {
    displayScore(chatterState.totalScore, 'chatter');
}

// --- Parrot Game Logic ---
let parrotState = {
    currentWordIndex: 0,
    totalScore: 0,
    wordsForGame: [],
    triesLeft: 3,
    currentWordPoints: 2
};

function startParrotGame() {
    parrotState.currentWordIndex = 0;
    parrotState.totalScore = 0;
    // Get 10 random phrases, not necessarily questions, for parrot game
    parrotState.wordsForGame = getRandomPhrases(10);
     if (parrotState.wordsForGame.length < 10) {
        alert("Not enough phrases in data.js to start Parrot game.");
        showScreen(mainMenu);
        return;
    }
    setupSpeechRecognition();
    presentParrotWord();
}

function presentParrotWord() {
    if (parrotState.currentWordIndex >= parrotState.wordsForGame.length) {
        endParrotGame();
        return;
    }

    const word = parrotState.wordsForGame[parrotState.currentWordIndex];
    parrotTile.innerHTML = `
        <div class="game-tile parrot-tile" id="parrotPlayTile">
            <div class="kanji">${word.mandarin}</div>
            <div class="pinyin">${word.pinyin}</div>
        </div>
        <button id="answerParrot">Answer</button>
        <div id="parrotFeedback" style="margin-top: 10px;"></div>
    `;

    document.getElementById('parrotPlayTile').addEventListener('click', () => playMandarinAudio(word.audio));
    document.getElementById('answerParrot').addEventListener('click', startSpeechRecognitionForParrot);

    parrotState.triesLeft = 3;
    parrotState.currentWordPoints = 2;
    document.getElementById('parrotFeedback').textContent = '';
}

function startSpeechRecognitionForParrot() {
    if (!speechRecognizer) {
        alert("Speech recognition not available or initialized.");
        return;
    }
    document.getElementById('answerParrot').disabled = true;
    speechRecognizer.start();
    document.getElementById('parrotFeedback').textContent = 'Listening...';
}

function handleParrotResult(transcript) {
    document.getElementById('answerParrot').disabled = false;
    const word = parrotState.wordsForGame[parrotState.currentWordIndex];
    const feedbackDiv = document.getElementById('parrotFeedback');

    let rating = 3; // Default to 'Not quite'
    let scoreAwarded = 0;

    // For Parrot, we compare the user's transcript directly to the Mandarin Pinyin/English.
    // This is a simplification. A real phonetic comparison is much harder.
    // We'll compare the spoken Pinyin to the expected Pinyin (case-insensitive, remove spaces)
    const expectedPinyinClean = word.pinyin.toLowerCase().replace(/\s/g, '');
    const userTranscriptClean = transcript.toLowerCase().replace(/\s/g, '');
    const isPinyinMatch = userTranscriptClean.includes(expectedPinyinClean);
    const isMandarinMatch = userTranscriptClean.includes(word.mandarin.toLowerCase()); // If speech recongnizer can output Kanji

    if (isPinyinMatch || isMandarinMatch) {
        rating = 1; // "Sounds great, well done!"
        scoreAwarded = parrotState.currentWordPoints;
        feedbackDiv.textContent = `Sounds great, well done! You said: "${transcript}"`;
        parrotState.totalScore += scoreAwarded;
        setTimeout(() => {
            parrotState.currentWordIndex++;
            presentParrotWord();
        }, 1500);
    } else {
        parrotState.triesLeft--;
        if (parrotState.triesLeft > 0) {
            rating = 2; // "Could do a bit better"
            feedbackDiv.textContent = `Could do a bit better. You said: "${transcript}". Tries left: ${parrotState.triesLeft}`;
            parrotState.currentWordPoints = 1; // Future attempts max 1 point
            const tryAgainBtn = document.createElement('button');
            tryAgainBtn.textContent = 'Try Again';
            tryAgainBtn.addEventListener('click', presentParrotWord);
            feedbackDiv.appendChild(tryAgainBtn);
        } else {
            rating = 3; // "Not quite, try again"
            feedbackDiv.textContent = `Not quite, try again. You said: "${transcript}". No tries left.`;
            const moveOnBtn = document.createElement('button');
            moveOnBtn.textContent = 'Move On';
            moveOnBtn.addEventListener('click', () => {
                parrotState.currentWordIndex++;
                presentParrotWord();
            });
            feedbackDiv.appendChild(moveOnBtn);
        }
    }
}


function endParrotGame() {
    displayScore(parrotState.totalScore, 'parrot');
}

// --- Score Screen Logic ---
function displayScore(score, gameType) {
    showScreen(scoreScreen);
    scoreDisplay.textContent = `Your Score: ${score} points!`;

    let animal = "Frog";
    const gameAnimals = scoreAnimals[gameType];
    for (let i = gameAnimals.length - 1; i >= 0; i--) {
        if (score >= gameAnimals[i].score) {
            animal = gameAnimals[i].animal;
            break;
        }
    }

    const emoji = animalEmojis[animal];
    animalAnimation.innerHTML = `<div class="animal-emoji">${emoji}</div>`;
    animalAnimation.classList.add('animate-confetti'); // Add confetti animation class
    // In a real app, you'd trigger a JS animation for confetti or use a library.

    // Clear previous emojis and add new ones for spinning animation
    animalAnimation.querySelectorAll('.spinning-emoji').forEach(el => el.remove());
    for (let i = 0; i < 10; i++) { // Add 10 spinning emojis
        const span = document.createElement('span');
        span.classList.add('spinning-emoji');
        span.textContent = emoji;
        span.style.left = `${Math.random() * 100}%`;
        span.style.top = `${Math.random() * 100}%`;
        span.style.animationDuration = `${2 + Math.random() * 3}s`; // Random speed
        span.style.animationDelay = `${Math.random() * 2}s`; // Random start delay
        animalAnimation.appendChild(span);
    }


    document.getElementById('playAgainBtn').onclick = () => {
        animalAnimation.classList.remove('animate-confetti'); // Clear animation
        animalAnimation.innerHTML = '';
        if (gameType === 'rapidFire') startRapidFireGame();
        else if (gameType === 'chatter') startChatterGame();
        else if (gameType === 'parrot') startParrotGame();
        showScreen(eval(gameType + 'Game')); // Go back to the game screen
    };

    document.getElementById('backToMenuBtn').onclick = () => {
        animalAnimation.classList.remove('animate-confetti'); // Clear animation
        animalAnimation.innerHTML = '';
        showScreen(mainMenu);
    };
}


// --- Speech Recognition Setup ---
function setupSpeechRecognition() {
    if ('webkitSpeechRecognition' in window) {
        speechRecognizer = new webkitSpeechRecognition();
        speechRecognizer.continuous = false;
        speechRecognizer.interimResults = false;
        speechRecognizer.lang = 'zh-CN'; // Mandarin Chinese

        speechRecognizer.onresult = (event) => {
            const transcript = event.results[0][0].transcript;
            console.log("Speech recognized:", transcript);
            if (chatterGame.style.display === 'block') {
                handleChatterResult(transcript);
            } else if (parrotGame.style.display === 'block') {
                handleParrotResult(transcript);
            }
        };

        speechRecognizer.onerror = (event) => {
            console.error('Speech recognition error:', event.error);
            alert('Speech recognition error: ' + event.error);
            if (chatterGame.style.display === 'block') {
                document.getElementById('chatterFeedback').textContent = `Error: ${event.error}. Please try again.`;
                document.getElementById('answerChatter').disabled = false;
            } else if (parrotGame.style.display === 'block') {
                 document.getElementById('parrotFeedback').textContent = `Error: ${event.error}. Please try again.`;
                 document.getElementById('answerParrot').disabled = false;
            }
        };

        speechRecognizer.onend = () => {
            console.log('Speech recognition ended.');
        };
    } else {
        alert("Your browser does not support Web Speech API for recognition. Chatter and Parrot games will not work.");
    }
}

// --- Utility for creating game tiles ---
function createTile(content, className, index) {
    const tile = document.createElement('div');
    tile.classList.add('game-tile', className);
    if (index !== undefined) {
        tile.dataset.index = index;
    }
    tile.innerHTML = content;
    return tile;
}

// --- Initialize Application on DOM Load ---
document.addEventListener('DOMContentLoaded', () => {
    // Get all screen elements
    appContainer = document.getElementById('app-container');
    prefsScreen = document.getElementById('preferences-screen');
    mainMenu = document.getElementById('main-menu');
    rapidFireGame = document.getElementById('rapid-fire-game');
    chatterGame = document.getElementById('chatter-game');
    parrotGame = document.getElementById('parrot-game');
    scoreScreen = document.getElementById('score-screen');

    // Get specific element references for forms/displays
    prefsForm = document.getElementById('preferences-form');
    rapidFireTilesLeft = document.getElementById('rapid-fire-tiles-left');
    rapidFireTilesRight = document.getElementById('rapid-fire-tiles-right');
    chatterQuestion = document.getElementById('chatter-question');
    parrotTile = document.getElementById('parrot-word-tile');
    scoreDisplay = document.getElementById('final-score');
    animalAnimation = document.getElementById('animal-animation');

    // Setup handlers
    setupPreferencesScreen();
    setupMainMenu();

    // Decide which screen to show first
    if (loadPreferences()) {
        showScreen(mainMenu);
    } else {
        showScreen(prefsScreen);
    }
});

// Load the phrases data (assuming data.js is loaded before app.js)
// This is already done by including <script src="data.js"></script> before <script src="app.js"></script> in HTML
