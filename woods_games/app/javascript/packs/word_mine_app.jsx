import React from 'react'
import ReactDOM from 'react-dom'
import PropTypes from 'prop-types'
import 'jquery'
import { Toast, ToastBody, ToastHeader, Spinner } from 'reactstrap';
import Cookies from 'js-cookie'

import Lobby from '../src/word_mine/lobby'
import Table from "../src/word_mine/table";

import 'bootstrap/dist/css/bootstrap.min.css';
import "../stylesheets/word_mine/game.css"
import "../stylesheets/word_mine/cards.css"

// a little function to help us with reordering the result
const reorder = (list, startIndex, endIndex) => {
    const result = Array.from(list);
    const [removed] = result.splice(startIndex, 1);
    result.splice(endIndex, 0, removed);

    return result;
};

const addTo = (list, value, index) => {
    const result = Array.from(list);
    result.splice(index, 0, value);
    return result;
};

const remove = (list, index) => {
    const result = Array.from(list);
    result.splice(index, 1);
    return result;
}

/**
 * Moves an item from one list to another list.
 */
const move = (source, destination, droppableSource, droppableDestination) => {
    const sourceClone = Array.from(source);
    const destClone = Array.from(destination);
    const [removed] = sourceClone.splice(droppableSource.index, 1);

    destClone.splice(droppableDestination.index, 0, removed);

    return [sourceClone, destClone];
};

function shuffle(array) {

    var currentIndex = array.length;
    var temporaryValue, randomIndex;

    // While there remain elements to shuffle...
    while (0 !== currentIndex) {
        // Pick a remaining element...
        randomIndex = Math.floor(Math.random() * currentIndex);
        currentIndex -= 1;

        // And swap it with the current element.
        temporaryValue = array[currentIndex];
        array[currentIndex] = array[randomIndex];
        array[randomIndex] = temporaryValue;
    }

    return array;

};

class WordMine extends React.Component {

    constructor(props) {
        super(props);

        this.player_cookie = "player_" + props.gameId;

        this.state = {
            requestState: 'NONE',
            handOrder: [],
            game: null,
            player: null,
            tempDiscard: null,
            layingDown: null,
            layingDownDiscard: null,
            toast: null,
            playingTurnDing: false
        };

        this.onAjaxError = this.onAjaxError.bind(this);
        this.refreshGameData = this.refreshGameData.bind(this);
        this.reconcileHand = this.reconcileHand.bind(this);
        this.addPlayer = this.addPlayer.bind(this);
        this.updateSettings = this.updateSettings.bind(this);
        this.startGame = this.startGame.bind(this);
        this.drawCard = this.drawCard.bind(this);
        this.discardCard = this.discardCard.bind(this);
        this.laydown = this.laydown.bind(this);
        this.laydownTypeBoxChange = this.laydownTypeBoxChange.bind(this);
        this.cancelLaydown = this.cancelLaydown.bind(this);
        this.shuffleHand = this.shuffleHand.bind(this);
        this.startNextRound = this.startNextRound.bind(this);
        this.startNewGame = this.startNewGame.bind(this);
        this.dismissToast = this.dismissToast.bind(this);
        this.turnDingDone = this.turnDingDone.bind(this);
        this.computeWords = this.computeWords.bind(this);

        this.onDragEnd = this.onDragEnd.bind(this);
    }

    componentDidMount() {
        console.log("Mounted.  Kicking off first state load");

        this.refreshGameData();
        this.loadWordList();

        this.interval = setInterval(this.refreshGameData, 1000);
    }

    componentWillUnmount() {
        clearInterval(this.interval);
    }

    loadWordList() {
        let needLoad = true;
        if (typeof(Storage) !== "undefined") {
            // Code for localStorage/sessionStorage.
            const wordData = localStorage.getItem("wordList_csw19");
            if (wordData) {
                const wordList = {};
                const words = wordData.split("\n");
                for (var i = 0; i < words.length; i++) wordList[words[i]] = true;
                console.log("FROM CACHE.  Loaded CSW19.  Words: ", words.length);
                this.setState({wordList: wordList});
                needLoad = false;
            }
        } else {
            console.log("No webstorage support.  Loading from web.");
        }

        if (needLoad) {
            $.ajax({
                url: window.csw19Path, //basePath + "csw15.txt",
                type: 'GET',
                success: (response) => {
                    if (typeof(Storage) !== "undefined") {
                        try {
                            localStorage.setItem("wordList_csw19", response);
                        } catch(err) {
                            console.log("Unable to cache wordlist", err);
                        }
                    }
                    const wordList = {};
                    const words = response.split("\n");
                    for (var i = 0; i < words.length; i++) wordList[words[i]] = true;
                    console.log("Loaded CSW19.  Words: ", words.length);
                    this.setState({wordList: wordList});
                },
                error: this.onAjaxError
            });
        }
    }

    // called every interval and initially on page load
    refreshGameData() {
        //only attempt to refresh data if we aren't already making a call
        if (this.state.requestState == 'NONE') {
            this.setState({requestState: 'REFRESHING'})

            $.ajax({
                url: this.props.gamePath,
                type: 'GET',
                success: (response) => {
                    const game = response.data;
                    game.room = response.room;
                    const lastServerAction = Date.parse(response.updated_at);
                    let dt = ((new Date()) - lastServerAction) / 1000.0 / 60.0 ;
                    if (dt > 10) {
                        console.log("Detected inactive game.");
                        this.setState({requestState: "INACTIVE", toast: "Inactive game detected.  Refresh the page to restart it."});
                        return;
                    }

                    var player = Cookies.get(this.player_cookie);
                    if (!game.players.includes(player)) {
                        player = null;
                        Cookies.remove(this.player_cookie)
                    }

                    if (this.state.game && this.state.game.table_state && game && game.table_state &&
                        this.state.game.table_state.active_player != game.table_state.active_player && game.table_state.active_player == player) {
                        //it is now this players turn
                        this.setState({playingTurnDing: true});
                    }
                    this.setState({requestState: 'NONE', game: game, player: player, handOrder: this.reconcileHand(game, player)});
                },
                error: this.onAjaxError
            });
        } else {
            console.log("Skipping update.  State: ", this.state.requestState);
        }
    }

    // return a new ordered hand state based on the new hand
    // Two cases:
    // hand contains new items: add them to the end
    //
    reconcileHand(game, player) {
        if (player === undefined) {
            player = this.state.player;
        }
        if (!(player && game.state == "PLAYING" && game.table_state && game.table_state.hands)) {
            return [];
        }
        const allLaidDown = (this.state.layingDown || []).flat();
        if (this.state.layingDownDiscard) allLaidDown.push(this.state.layingDownDiscard);
        const hand = game.table_state.hands[player];
        const inBoth = this.state.handOrder.filter((cI) => hand.includes(cI));
        const newCards = hand.filter((cI) => !this.state.handOrder.includes(cI) && !allLaidDown.includes(cI));

        return inBoth.concat(newCards);
    }

    shuffleHand() {
        console.log("SHUFFLE HAND: ", this.state.handOrder);
        if (this.state.handOrder) {
            const handOrder = Array.from(this.state.handOrder);
            shuffle(handOrder);
            this.setState({handOrder: handOrder});
        }
    }

    addPlayer(player) {
        if (this.state.requestState == "ACTING") {
            console.warn("Action already in progress.  Skipping");
            return;
        }

        this.setState({requestState: 'ACTING'} )

        $.ajax({
            url: this.props.gamePath + "/player",
            type: 'POST',
            data: {player: player},
            success: (response) => {
                // Jets does not let us set non http_only cookies, so write the cookie here
                Cookies.set(this.player_cookie, player);
                this.setState({requestState: 'NONE', game: response.data, player: player })
            },
            error: this.onAjaxError
        });
    }

    updateSettings(settings) {
        if (this.state.requestState == "ACTING") {
            console.warn("Action already in progress.  Skipping");
            return;
        }

        this.setState({requestState: 'ACTING'} )

        $.ajax({
            url: this.props.gamePath + "/settings",
            type: 'POST',
            dataType: 'json',
            contentType: 'application/json',
            data: JSON.stringify({settings: settings}),
            success: (response) => {
                this.setState({requestState: 'NONE', game: response.data})
            },
            error: this.onAjaxError
        });
    }

    startGame() {
        if (this.state.requestState == "ACTING") {
            console.warn("Action already in progress.  Skipping");
            return;
        }

        console.log("Start game!");
        this.setState({requestState: 'ACTING'} )

        $.ajax({
            url: this.props.gamePath + "/start",
            type: 'POST',
            success: (response) => this.setState({requestState: 'NONE', game: response.data }),
            error: this.onAjaxError
        });
    }

    drawCard(target) {
        if (this.state.requestState == "ACTING") {
            console.warn("Action already in progress.  Skipping");
            return;
        }

        console.log("DRAW CARD FROM: ", target);
        this.setState({requestState: 'ACTING'} )

        $.ajax({
            url: this.props.gamePath + "/draw",
            type: 'POST',
            data: {draw_type: target},
            success: (response) => this.setState({requestState: 'NONE', game: response.data, handOrder: this.reconcileHand(response.data)}, this.computeWords),
            error: this.onAjaxError
        });
    }

    discardCard(cI) {
        if (this.state.requestState == "ACTING") {
            console.warn("Action already in progress.  Skipping");
            return;
        }

        console.log("Discarding card: ", cI);
        this.setState({requestState: 'ACTING'} )

        $.ajax({
            url: this.props.gamePath + "/discard",
            type: 'POST',
            data: {card: cI},
            success: (response) => this.setState({requestState: 'NONE', game: response.data, handOrder: this.reconcileHand(response.data), tempDiscard: null }),
            error: this.onAjaxError
        });
    }

    layingDown() {
        const layingDown = {words: this.state.layingDown, leftover: this.state.handOrder, discard: this.state.layingDownDiscard};

        this.setState({requestState: 'REFRESHING'} )

        $.ajax({
            url: this.props.gamePath + "/layingdown",
            type: 'POST',
            data: {laydown: layingDown},
            success: (response) => this.setState({requestState: 'NONE'}),
            error: this.onAjaxError
        });
    }

    laydown() {
        console.log("Called laydown");
        let leftover = this.state.handOrder;
        let discard = this.state.layingDownDiscard;
        if (!discard && leftover.length == 1) {
            console.log("Using the last card in hand as the discard", leftover);
            discard = leftover.splice(0, 1)[0];
        }
        const layingDown = {words: this.state.layingDown, leftover: leftover, discard: discard};

        this.setState({requestState: 'ACTING'} )

        $.ajax({
            url: this.props.gamePath + "/laydown",
            type: 'POST',
            data: {laydown: layingDown},
            success: (response) => this.setState({requestState: 'NONE',
                game: response.data, layingDown: null, handOrder: [], layingDownDiscard: null}),
            error: this.onAjaxError
        });
    }

    startNextRound() {
        console.log(this.state.game['card_ev']);

        this.setState({requestState: 'ACTING'} )

        $.ajax({
            url: this.props.gamePath + "/round",
            type: 'POST',
            success: (response) => this.setState({requestState: 'NONE', game: response.data}),
            error: this.onAjaxError
        });
    }

    startNewGame() {
        this.setState({requestState: 'ACTING'} )

        $.ajax({
            url: this.props.gamePath + "/newgame",
            type: 'POST',
            success: (response) => this.setState({requestState: 'NONE', game: response.data}),
            error: this.onAjaxError
        });
    }

    onDragEnd(result) {
        let layingDown;
        const { source, destination } = result;

        // dropped outside the list
        if (!destination) {
            return;
        }
        console.log("Drag from: ", source.droppableId, " -> ", destination.droppableId);
        if (source.droppableId === destination.droppableId) {
            if (source.droppableId == 'playerHand') {
                this.setState({handOrder: reorder(this.state.handOrder, source.index, destination.index)});
            }
        }
    }

    turnDingDone() {
        this.setState({playingTurnDing: false});
    }

    laydownTypeBoxChange(event) {
        function cardsToWord(cardIndexes, deckMap) {
            let word = "";
            for(let i = 0; i < cardIndexes.length; i++) {
                word += deckMap[parseInt(cardIndexes[i])][0];
            }
            return(word);
        }

        //diff the current vs new and take an action based on the difference
        const deckMap = this.state.game.deck;
        const hand = this.state.handOrder;
        const layingDown = this.state.layingDown || [];
        const words = layingDown.map( (cardLetters) => cardsToWord(cardLetters, deckMap));
        const laydownFlat = layingDown.flat();
        const currentLaydown = words.join(" ");
        const newLaydown = event.target.value.toUpperCase();
        console.log(laydownFlat);
        console.log(currentLaydown);
        console.log(newLaydown);

        //two cases - subtraction and addition (ignore copy/paste and replace...)
        if (currentLaydown.length > newLaydown.length) {
            console.log("Deleted a letter");
            //figure out which letter was deleted, find the card and move it to the end of the hand
            for (var lI = 0, wI = 0, wordI = 0; lI < laydownFlat.length; lI++) {
                const cw = deckMap[parseInt(laydownFlat[lI])][0];
                if (currentLaydown[wI] === " ") {
                    if (newLaydown[wI] === " ") {
                        console.log("Skipping space");
                        wordI++;
                        wI++;
                    } else {
                        // A Space as deleted! Combine words
                        console.log("SPACE DELETED: wordI: ", wordI);
                        //combine wordI and wordI + 1
                        let newLayingDown = Array.from(this.state.layingDown);
                        newLayingDown[wordI] = newLayingDown[wordI].concat( newLayingDown.splice(wordI+1, 1)[0]);
                        this.setState({layingDown: newLayingDown}, this.layingDown);
                        return;
                    }
                }
                console.log(cw);
                if (newLaydown.substr(wI, cw.length) === cw) {
                    console.log(newLaydown.substr(wI, cw.length))
                } else {
                    console.log("DELETED: ", cw, laydownFlat[lI]);
                    let newLayingDown = Array.from(this.state.layingDown);
                    for(var i = 0; i < newLayingDown.length; i++) {
                        for(var j = 0; j < newLayingDown[i].length; j++) {
                            if (newLayingDown[i][j] === laydownFlat[lI]) {
                                console.log("Removing: ", i, j);
                                newLayingDown[i] = remove(newLayingDown[i], j);
                                hand.push(laydownFlat[lI]);
                                this.setState({layingDown: newLayingDown, handOrder: hand}, this.layingDown);
                                return;
                            }
                        }
                    }
                    console.log("Failed to find the right laydown to remove....");
                    return;
                }
                wI += cw.length;
            }

            if (currentLaydown[currentLaydown.length -1] == " ") {
                //gotten to the end, the current has a space.  Drop the last (empty) word
                console.log("Dropping an empty word at the end...");
                let newLayingDown = Array.from(this.state.layingDown);
                newLayingDown.splice(newLayingDown.length-1, 1);
                this.setState({layingDown: newLayingDown}, this.layingDown);
                return;
            }
            console.log("Something else went wrong and couldnt find the removed letter");
            return;
        }

        //Addition!  New letter!
        //easy case, no laydown started yet.
        if (currentLaydown.length == 0) {
            console.log("Starting a new laydown");
            for (var i = 0; i < hand.length; i++) {
                if (newLaydown == deckMap[parseInt(hand[i])][0]) {
                    console.log("Found single letter at: ", i);
                    const cI = hand[i];
                    this.setState({handOrder: remove(hand, i), layingDown: [[cI]]}, this.layingDown );
                    return;
                }
            }

            //check double letters
            for (var i = 0; i < hand.length; i++) {
                if (newLaydown == deckMap[parseInt(hand[i])][0][0]) { //compare only the first letter
                    console.log("Found double letter at: ", i);
                    const cI = hand[i];
                    this.setState({handOrder: remove(hand, i), layingDown: [[cI]]}, this.layingDown );
                    return;
                }
            }
        }

        var middleOfCard = false;
        for(var nI = 0, wordI = 0, letterCI = 0; nI < newLaydown.length; nI++) {
            if (newLaydown[nI] == currentLaydown[nI] && nI < currentLaydown.length) {
                if (newLaydown[nI] == " ") {
                    wordI ++;
                    letterCI = 0;
                } else {
                    const card = deckMap[parseInt(layingDown[wordI][letterCI])][0];
                    if (card.length > 1) {
                        if (!middleOfCard) {
                            middleOfCard = true;
                        } else {
                            middleOfCard = false;
                            letterCI++;
                        }
                    } else {
                        letterCI++;
                    }
                }
            } else {
                //found the addition!
                console.log("User entered new character: ", newLaydown[nI]);
                if (middleOfCard) {
                    console.log("New Entry is in the middle of a card.  NO GO!");
                    return;
                }
                if (newLaydown[nI] === " ") {
                    console.log("Adding a new word");
                    let newLayingDown = Array.from(this.state.layingDown);

                    if (nI >= (newLaydown.length - 1)) {
                        //at the end, just add it to the end if there isnt alraedy a blank word
                        if (newLayingDown[newLayingDown.length-1].length > 0) {
                            newLayingDown.push([]);
                            this.setState({layingDown: newLayingDown}, this.layingDown );
                        }
                    } else {
                        //split the word we are in
                        const splitWord = newLayingDown[wordI].splice(letterCI, newLayingDown[wordI].length-letterCI);
                        newLayingDown.splice(wordI+1, 0, splitWord);
                        this.setState({layingDown: newLayingDown}, this.layingDown );
                    }

                    return;
                } else {
                    // see if we have some cards to make a letter for this
                    for (var i = 0; i < hand.length; i++) {
                        if (newLaydown[nI] == deckMap[parseInt(hand[i])][0]) {
                            const cI = hand[i];
                            console.log("Found single letter at: ", i, cI);
                            let newLayingDown = Array.from(this.state.layingDown);
                            newLayingDown[wordI].splice(letterCI, 0, cI);
                            this.setState({handOrder: remove(hand, i), layingDown: newLayingDown}, this.layingDown );
                            return;
                        }
                    }

                    //check double letters
                    for (var i = 0; i < hand.length; i++) {
                        if (newLaydown[nI] == deckMap[parseInt(hand[i])][0][0]) { //compare only the first letter
                            const cI = hand[i];
                            console.log("Found double letter at: ", i, cI);
                            let newLayingDown = Array.from(this.state.layingDown);
                            newLayingDown[wordI].splice(letterCI, 0, cI);
                            this.setState({handOrder: remove(hand, i), layingDown: newLayingDown}, this.layingDown );
                            return;
                        }
                    }

                    // check for an UPGRADE to double letter
                    // added the second letter of a double letter
                    if (nI > 0) { //doesn't apply for first letter
                        for (let i = 0; i < hand.length; i++) {
                            const cardLetters = deckMap[parseInt(hand[i])][0];
                            if (cardLetters.length > 1
                                && newLaydown[nI-1] == cardLetters[0]
                                && newLaydown[nI] == cardLetters[1]) {
                                const cI = hand[i];
                                console.log("Found AN UPGRADE double letter at: ", i, cI);
                                let newLayingDown = Array.from(this.state.layingDown);

                                //move the current letter back to the hand and replace it with the double letter

                                const cardToRemove = newLayingDown[wordI].splice(letterCI-1, 1, cI)[0];
                                hand.push(cardToRemove);
                                this.setState({handOrder: remove(hand, i), layingDown: newLayingDown}, this.layingDown);
                                return;
                            }
                        }
                    }
                }
            }
        }

        //for each letter
        //check if it already matches a double (check next letter)
        //


        // //remove it from the handOrder
        // const wordI = parseInt(destination.droppableId.split("laydown_")[1]);
        // layingDown = Array.from(this.state.layingDown); //TODO: deep copy...
        // const moveRes = move(this.state.handOrder, layingDown[wordI], source, destination);
        // layingDown[wordI] = moveRes[1];
        //
        // this.setState({handOrder: moveRes[0], layingDown: layingDown}, this.layingDown);
    }

    cancelLaydown() {
        this.setState({layingDown: null, layingDownDiscard: null,
            handOrder: this.state.game.table_state.hands[this.state.player]}, this.layingDown);
    }

    dismissToast() {
        this.setState({toast: null});
    }

    // called after a card is drawn to compute possible word combinations
    computeWords() {
        console.log("Compute words: ");
    }

    render() {
        return(
            <div>
                {this.state.game
                    ? <Game game={this.state.game} player={this.state.player}
                            toast={this.state.toast}
                            tempDiscard={this.state.tempDiscard}
                            handOrder={this.state.handOrder}
                            layingDown={this.state.layingDown}
                            layingDownDiscard={this.state.layingDownDiscard}
                            wordList={this.state.wordList}
                            requestState={this.state.requestState}
                            playingTurnDing={this.state.playingTurnDing}
                            addPlayer={this.addPlayer}
                            updateSettings={this.updateSettings}
                            startGame={this.startGame}
                            drawCard={this.drawCard}
                            laydown={this.laydown}
                            laydownTypeBoxChange={this.laydownTypeBoxChange}
                            cancelLaydown={this.cancelLaydown}
                            shuffleHand={this.shuffleHand}
                            startNextRound={this.startNextRound}
                            startNewGame={this.startNewGame}
                            onDragEnd={this.onDragEnd}
                            dismissToast ={this.dismissToast}
                            turnDingDone={this.turnDingDone}
                    />
                    :
                    <div className="loading-overlay">
                        <div className="d-flex justify-content-center">
                            <Spinner animation="border" role="status" variant="primary">
                                Loading...
                            </Spinner>
                            <p>Initializing game state....</p>
                        </div>
                    </div>
                }
            </div>
        );
    }

    onAjaxError(request, xhr, textStatus, errorThrown ) {
        console.log("Error during AJAX request: ", xhr, textStatus, errorThrown);
        this.setState({ requestState: 'FAILED', toast: 'Please refresh the page. Request to server failed' });
    }

}

function Game(props) {
    return(
        <div>
            {props.game.state == 'WAITING_FOR_PLAYERS'
                ? <Lobby {...props} />
                : <Table {...props} />
            }
            {props.requestState == 'ACTING' &&
                <div className="loading-overlay">
                    <div className="d-flex justify-content-center">
                        <Spinner animation="border" role="status" variant="primary">
                            Loading...
                        </Spinner>
                    </div>
                </div>
            }
            <Toast className="warning-toast" isOpen={!!props.toast}>
                <ToastHeader icon="danger" toggle={props.dismissToast}>
                    Warning
                </ToastHeader>
                <ToastBody>
                    {props.toast}
                </ToastBody>
            </Toast>
        </div>
    )
}

document.addEventListener('DOMContentLoaded', () => {
    ReactDOM.render(
        <WordMine gameId={window.gameId} gamePath={window.gamePath}/>,
        document.body.appendChild(document.createElement('div')),
    )
})