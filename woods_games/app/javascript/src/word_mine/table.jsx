import React from 'react'
import ReactDOM from 'react-dom'
import PropTypes from 'prop-types'
import { DragDropContext, Droppable, Draggable } from 'react-beautiful-dnd';
import {Container, Row, Col, Input, FormGroup, UncontrolledCollapse} from 'reactstrap';
import { Modal, ModalBody, ModalHeader, ModalFooter} from 'reactstrap';

import { Button } from 'reactstrap';
import Sound from 'react-sound';

var classNames = require('classnames');


const getItemStyle = (isDragging, draggableStyle) => ({
    // some basic styles to make the items look a bit nicer
    userSelect: 'none',
    padding: 4,

    // change background colour if dragging
    background: isDragging ? 'lightgreen' : 'grey',

    // styles we need to apply on draggables
    ...draggableStyle
});

const getListStyle = isDraggingOver => ({
    background: isDraggingOver ? 'lightblue' : 'lightgrey',
    display: "flex",
    padding: "2px 2px 2px 2px",
    marginRight: "50px"
});

const getDiscardListStyle = isDraggingOver => ({
    background: isDraggingOver ? 'lightblue' : 'white',
    opacity: isDraggingOver ? '50%' : '0%',
    display: "flex",
    position: "absolute",
    width: "90px",
    height: "110px",
    top: "-5px",
    left: "10px"
});

const getNewWordListStyle = isDraggingOver => ({
    background: isDraggingOver ? 'lightblue' : 'lightgrey',
    display: "flex",
    minWidth: "90px",
    minHeight: "110px"
});

const getLaydownDiscardListStyle = isDraggingOver => ({
    background: isDraggingOver ? 'lightblue' : 'lightgrey',
    display: "flex",
    minWidth: "90px",
    minHeight: "110px"
});

function cardsToWord(cardIndexes, deckMap) {
    let word = "";
    for(let i = 0; i < cardIndexes.length; i++) {
        word += deckMap[parseInt(cardIndexes[i])][0];
    }
    return(word);
}

function isWordValid(word, wordList) {
    if (wordList && Object.keys(wordList).length > 1000) {
        return word.length >= 2 && wordList[word] !== undefined;
    } else {
        return word.length >= 3;
    }
}

export default class Table extends React.Component {

    render() {

        const others = this.props.game.players.filter( p => p != this.props.player );
        const players = others.map(player =>
            <Player key={player} player={player} game={this.props.game}/>
        );
        return (
            <Container style={{maxWidth: '1200px'}}>
                <Row className="mt-3">
                    <Col md={3}>
                        {players}
                    </Col>
                    <Col xs="auto">
                        <MineShafts game={this.props.game}
                                      player={this.props.player}
                                      playerAction={this.props.playerAction}
                                      selectWordBuildCard={this.props.selectWordBuildCard}
                        />
                    </Col>
                </Row>
                <Row>
                    {/* Use key to force a full re-render when the active player changes*/}
                    <PlayerSpace game={this.props.game} 
                                 player={this.props.player}
                                 playerAction={this.props.playerAction}
                                 onDragEnd={this.props.onDragEnd}
                                 handOrder={this.props.handOrder}
                                 startWordBuildSelect={this.props.startWordBuildSelect}
                                 inProgressWord={this.props.inProgressWord}
                                 wordBuildTypeBoxChange={this.props.wordBuildTypeBoxChange}
                                 buildHand={this.props.buildHand}
                                 cancelWordBuild={this.props.cancelWordBuild}
                                 submitWordBuild={this.props.submitWordBuild}
                                 wordList={this.props.wordList}
                                 wordBuildCard={this.props.wordBuildCard}
                                 drawCard={this.props.drawCard}
                                 shuffleDiscard={this.props.shuffleDiscard}
                                 layingDown={this.props.layingDown}
                                 shuffleHand={this.props.shuffleHand}
                                 playingTurnDing={this.props.playingTurnDing}
                                 turnDingDone={this.props.turnDingDone}
                    />
                </Row>
                {this.props.game.settings && this.props.game.settings.bonus_words &&
                <Row>
                    <a href={window.bonus_wordlists[this.props.game.settings.bonus_words]} target='#'>Bonus word list: {this.props.game.settings.bonus_words}</a>
                </Row>
                }
                <Row>
                    <a href={window.dictionaryPath} target='#'>Word Mine Dictionary</a>
                </Row>
            </Container>
        );
    }
}

function Player(props) {
    const player = props.player;
    const tableState = props.game.table_state;
    const isActivePlayer = props.player == tableState.active_player;

    const playerState = tableState.players_state[player];

    return(
        <Row className={classNames({"active-player": isActivePlayer}, "player")}>
            <div className="player-left pl-1">
                <div className="player-name">{props.player}</div>
                <div className="player-score">Score: {parseInt(playerState.score)}</div>
            </div>
            <div className="player-right">
                Hand: {playerState.deck.length} Deck: {playerState.hand.length} Discard: {playerState.discard.length}
            </div>
        </Row>
    );
}

// The rows of cards to chose from
function MineShafts(props) {
    const deckMap = props.game.deck.map( (card) => [ card[0], parseInt(card[1]), parseInt(card[2])]);;
    const tableState = props.game.table_state;
    const laidOut = tableState.laid_out;
    const decks = tableState.decks;
    const myTurn = props.player == props.game.table_state.active_player;
    const selecting = myTurn && props.playerAction === 'PICKING_WORD_BUILD_CARD';


    const rows = laidOut.map( (layOut, rowI) => {
        const rowCards = layOut.map((cardI, colI) =>
            <ZCard key={cardI} card={deckMap[parseInt(cardI)]}
                onClick={(e) => selecting && props.selectWordBuildCard(e, parseInt(cardI), rowI, colI) }
            />
        );
        return (
            <Row key={rowI}>
                {rowCards}
                <div className='mine-shaft-deck'>
                    <Col md="auto" className="my-auto">
                        <div className={`deck deck-${rowI}`} onClick={() => myDraw && props.drawCard("DECK")} />
                    </Col>
                </div>
            </Row>
        )
    });

    return(
        <div className={classNames('mine-shafts', {'my-turn': selecting })}>
            {rows}
        </div>
    );
}



function WordBuildTypeBox(props) {
    const words = props.inProgressWord ?
        props.inProgressWord.map( (cardLetters) => cardsToWord(cardLetters, props.deckMap))
        : [""];

    const cardsInWord = props.inProgressWord ? props.inProgressWord.flat() : [];

    const singleWord = words.join("");
    const issues = []; //add validation issues to this

    // Rules
    // must be 3+ CARDS
    // must be a valid word
    // must contain the selected card
    if (cardsInWord.length < 3) {
        issues.push("Word must contain at least 3 cards.");
    }
    if (!isWordValid(singleWord, props.wordList)) {
        issues.push("Word must be in the dictionary.")
    }
    if (!cardsInWord.includes(props.wordBuildCard["cardI"])) {
        issues.push("Word must use the selected card.");
    }

    const issueList = issues.map( (issue, i) =>
        <li key={i}>{issue}</li>
    );

    const wordValid = issues.length == 0;

    return(
        <div>
            <Input type="text" name="wordBuildTypeBox" id="wordBuildTypeBox"
                   className={wordValid ? "laydown-word-valid" : "laydown-word-invalid"}
                   placeholder="Build a word" autoComplete="off"
                   value={words.join(" ")} onChange={props.wordBuildTypeBoxChange}
                   autoFocus={true}
            />
            {!wordValid && "Issues: "}
            <ul>
                {issueList}
            </ul>
        </div>
    );
}

function PlayerActionModal(props) {
    const myTurn = props.player == props.game.table_state.active_player;

    return(
      <Modal fullscreen="md" isOpen={myTurn && !props.playerAction}>
          <ModalHeader>
              Its your turn - choose an action!
          </ModalHeader>
          <ModalBody>
              You can build words, reshuffle your deck or draw more cards.
          </ModalBody>
          <ModalFooter>
              <Button color="primary" onClick={props.startWordBuildSelect} >
                  Build a word
              </Button>
              <Button color="primary" onClick={props.drawCard}>
                  Draw
              </Button>
              <Button color="primary" onClick={props.shuffleDiscard}>
                  Shuffle Discard to Deck
              </Button>
          </ModalFooter>
      </Modal>
    );
}

function WordBuildModal(props) {
    const myTurn = props.player == props.game.table_state.active_player;
    const deckMap = props.game.deck;

    const wordBuildCard = props.wordBuildCard;
    const wbCardUsed = !props.buildHand.includes(wordBuildCard.cardI);
    const handCards = props.buildHand.filter( (cI) => cI !== wordBuildCard.cardI);
    console.log(wordBuildCard, wbCardUsed, handCards);

    const handZCards = handCards.map( (cI) =>
        <ZCard key={cI} card={deckMap[parseInt(cI)]} />
    )

    return(
        <Modal fullscreen="md" isOpen={true} autoFocus={false} toggle={props.cancelWordBuild}>
            <ModalHeader>
                Build a word
            </ModalHeader>
            <ModalBody>
                <WordBuildTypeBox
                    inProgressWord={props.inProgressWord}
                    wordBuildTypeBoxChange={props.wordBuildTypeBoxChange}
                    deckMap={deckMap}
                    wordList={props.wordList}
                    wordBuildCard={props.wordBuildCard}
                />
                <div className="word-build-cards">
                    <ZCard className={classNames("selected-card", {used: wbCardUsed})} card={deckMap[wordBuildCard.cardI]} />
                    {handZCards}
                </div>
            </ModalBody>
            <ModalFooter>
                <Button color="primary" onClick={props.submitWordBuild} >
                    Build it!
                </Button>
                <Button color="secondary" onClick={props.cancelWordBuild}>
                    Cancel
                </Button>
            </ModalFooter>
        </Modal>
    );
}


// players hand + actions
class PlayerSpace extends React.Component {

    render() {
        const deckMap = this.props.game.deck.map( (card) => [ card[0], parseInt(card[1]), parseInt(card[2])]);;
        const tableState = this.props.game.table_state;
        const hand = this.props.handOrder.map(cI => parseInt(cI));
        const myTurn = this.props.player == this.props.game.table_state.active_player;
        const playStatus = this.props.playingTurnDing ? Sound.status.PLAYING : Sound.status.STOPPED;
        const playerState = tableState.players_state[this.props.player]

        const handCards = hand.map((cI, index) =>
            <Draggable
                key={cI}
                draggableId={cI.toString()}
                index={index}>
                {(provided, snapshot) => (
                    <div
                        ref={provided.innerRef}
                        {...provided.draggableProps}
                        {...provided.dragHandleProps}
                        style={getItemStyle(
                            snapshot.isDragging,
                            provided.draggableProps.style
                        )}>
                        <ZCard card={deckMap[cI]} key={cI}/>
                    </div>
                )}
            </Draggable>
        );
        return (
            <span className={classNames('player-space')}>
                <PlayerActionModal {...this.props} />
                {myTurn && this.props.playerAction === "BUILDING_WORD" && <WordBuildModal {...this.props} /> }
                <div className="pl-1">
                    <div className="player-name">{this.props.player}</div>
                    <div className="player-score">Score: {parseInt(this.props.game.table_state.players_state[this.props.player].score)}</div>
                </div>
                {myTurn &&
                <Sound url={window.notificationPath} playStatus={playStatus} loop={false} onFinishedPlaying={this.props.turnDingDone}/>
                }

                <DragDropContext onDragEnd={this.props.onDragEnd}>
                    <Col md={'auto'} className={classNames('mt-3')}>
                        <Droppable droppableId='playerHand' direction="horizontal" >
                            {(provided, snapshot) => (
                                <div
                                    ref={provided.innerRef}
                                    style={getListStyle(snapshot.isDraggingOver)}>
                                    {handCards}
                                    {provided.placeholder}
                                </div>
                            )}
                        </Droppable>
                    </Col>
                    <Button color="secondary" onClick={this.props.shuffleHand}>Shuffle Hand</Button>
                </DragDropContext>
                <div>
                    Deck: {playerState.deck.length} Discard: {playerState.discard.length}
                </div>
            </span>
        )
    }
}

function ZCard(props) {
    // props.selectable
    return(
        <section className={classNames("card", props.className)} value={props.card[0]} onClick={props.onClick}>
            <section className="card-number" value={parseInt(props.card[1])} >
                <div className="card__inner card__inner--centered">
                    <div className="card__column">
                        <div className={`card__symbol card-rarity-${parseInt(props.card[2])}`}>{props.card[0]}</div>
                    </div>
                </div>
            </section>
        </section>
    );
}