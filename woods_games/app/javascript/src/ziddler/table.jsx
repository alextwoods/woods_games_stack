import React from 'react'
import ReactDOM from 'react-dom'
import PropTypes from 'prop-types'
import { DragDropContext, Droppable, Draggable } from 'react-beautiful-dnd';
import {Container, Row, Col, Input, FormGroup} from 'reactstrap';
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
        return word.length == 0 || (word.length >= 2 && wordList[word] !== undefined);
    } else {
        return word.length == 0 || word.length >= 2;
    }
}

export default class Table extends React.Component {

    render() {
        if (this.props.game.table_state['turn_state'] === "ROUND_COMPLETE") {
            return(
                <RoundSummary game={this.props.game} player={this.props.player}
                              startNextRound={this.props.startNextRound}
                              startNewGame={this.props.startNewGame}
                />
            );
        }

        const others = this.props.game.players.filter( p => p != this.props.player );
        const players = others.map(player =>
            <Player key={player} player={player} game={this.props.game}/>
        );
        return (
            <DragDropContext onDragEnd={this.props.onDragEnd}>
                <Container style={{maxWidth: '1200px'}}>
                    <Row className="mt-3">
                        <Col md={3}>
                            {players}
                        </Col>
                        <Col xs="auto">
                            <DeckSpace game={this.props.game} player={this.props.player}
                                       tempDiscard={this.props.tempDiscard}
                                       layingDown={this.props.layingDown}
                                       laydown={this.props.laydown}
                                       layingDownDiscard={this.props.layingDownDiscard}
                                       laydownTypeBoxChange={this.props.laydownTypeBoxChange}
                                       handOrder={this.props.handOrder}
                                       wordList={this.props.wordList}
                                       cancelLaydown={this.props.cancelLaydown}
                                       drawCard={this.props.drawCard}
                            />
                        </Col>
                    </Row>
                    <Row>
                        {/* Use key to force a full re-render when the active player changes*/}
                        <PlayerSpace game={this.props.game} player={this.props.player}
                                     handOrder={this.props.handOrder}
                                     layingDown={this.props.layingDown}
                                     shuffleHand={this.props.shuffleHand}
                                     key={this.props.game.table_state.turn}
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
                        <a href={window.dictionaryPath} target='#'>Ziddler Dictionary</a>
                    </Row>
                </Container>
            </DragDropContext>
        );
    }
}

function Player(props) {
    const player = props.player;
    const tableState = props.game.table_state;
    const deckMap = props.game.deck;
    const isActivePlayer = props.player == tableState.active_player;

    const isLayingDown = !!tableState.laying_down;
    const isLaidDown = !!tableState.laid_down[player];
    const laidDown = tableState.laid_down[player] || (isActivePlayer && tableState.laying_down);

    let playerState  = "";
    if (isActivePlayer) {
        if (tableState.turn_state == "WAITING_TO_DRAW") playerState = "Drawing...";
        if (tableState.turn_state == "WAITING_TO_DISCARD") playerState = "Playing...";
        if (isLayingDown) playerState = "Laying Down...";
    }

    return(
        <Row className={classNames({"active-player": isActivePlayer}, "player")}>
            <div className="player-left pl-1">
                <div className="player-name">{props.player}</div>
                <div className="player-score">Score: {parseInt(props.game.score[props.player])}</div>
                {isActivePlayer &&
                <div className="player-state">{playerState}</div>
                }
            </div>
            <div className="player-right">
                {!laidDown &&
                <div className='cards-hand cards-small'>
                    {tableState.hands[props.player].map( (cI, index) =>
                        <div key={cI} className='card-back' style={{marginLeft: (10*index) + "px"}}/>
                    )}
                </div>
                }
                {laidDown &&
                <div className='cards-laydown cards-tiny'>
                    {laidDown.cards.map((wordCards, wordI) =>
                        <Row key={wordI}>
                            {wordCards.map((cI) =>
                                <ZCard key={cI} card={deckMap[parseInt(cI)]}/>
                            )}
                        </Row>
                    )}
                    {laidDown.leftover.length > 0 &&
                    <Row className="laydown-word-leftover">
                        {laidDown.leftover.map((cI) =>
                            <ZCard key={cI} card={deckMap[parseInt(cI)]}/>
                        )}
                    </Row>
                    }
                </div>
                }
            </div>
        </Row>
    );
}

// Deck + Discard
function DeckSpace(props) {
    const deckMap = props.game.deck;
    const tableState = props.game.table_state;
    const deck = tableState.deck;
    const discard = parseInt(tableState.discard[[tableState.discard.length - 1]]);
    const myTurn = props.player == props.game.table_state.active_player;
    const myDraw = myTurn && tableState.turn_state == "WAITING_TO_DRAW";
    const myDiscard = myTurn && tableState.turn_state == "WAITING_TO_DISCARD";
    const lastTurn = !$.isEmptyObject(props.game.table_state.laid_down);
    const canDiscard = myDiscard && !props.layingDown;

    const myLaydownComplete = lastTurn && !$.isEmptyObject(props.game.table_state.laid_down[props.player]);

    return(
        <div>
            {!props.layingDown &&
            <Row className={classNames({'my-draw': myDraw})}>
                <Col md="auto" className="my-auto">
                    <div className="deck" onClick={() => myDraw && props.drawCard("DECK")} />
                </Col>
                <Col>
                    {!canDiscard &&
                    <ZCard card={deckMap[discard]} onClick={() => myDraw && props.drawCard("DISCARD")}/>
                    }
                    {canDiscard &&
                    <DroppableDiscard deckMap={deckMap} discard={discard} layingDown={props.layingDown}
                                      tempDiscard={props.tempDiscard}/>
                    }
                </Col>
                <Col>
                    <div className={"game-state-info"}>Turn: {parseInt(tableState.turn)}
                        <br/>Player: {props.game.table_state.active_player}</div>
                </Col>
            </Row>
            }
            {myDiscard &&
            <DroppableLaydown layingDown={props.layingDown} deckMap={deckMap}
                              lastTurn={lastTurn}
                              handOrder={props.handOrder}
                              layingDownDiscard={props.layingDownDiscard}
                              laydownTypeBoxChange={props.laydownTypeBoxChange}
                              cancelLaydown={props.cancelLaydown} wordList={props.wordList}
                              laydown={props.laydown}/>
            }

        </div>
    )
}

function DroppableDiscard(props) {
    const discardI = props.tempDiscard || props.discard;
    return(
        <span style={{display: "flex"}}>
            <ZCard card={props.deckMap[discardI]} />
            <Droppable droppableId='discardPile' direction="horizontal">
                {(provided, snapshot) => {
                    return (
                        <div
                            ref={provided.innerRef}
                            style={getDiscardListStyle(snapshot.isDraggingOver)}>

                            {provided.placeholder}
                        </div>);
                }}
            </Droppable>
        </span>
    );
}

function DroppableLaydown(props) {
    if (!props.layingDown) {
        return(
            <div>
                <Droppable droppableId='newLaydownWord' direction="horizontal">
                    {(provided, snapshot) => (
                        <div
                            ref={provided.innerRef}
                            style={getNewWordListStyle(snapshot.isDraggingOver)}>
                            <div className="laydown-new-word">Laydown</div>
                            {provided.placeholder}
                        </div>
                    )}
                </Droppable>
                <LaydownTypeBox {...props} />
            </div>
        );
    } else {
        const words = props.layingDown.map( (cardLetters) => cardsToWord(cardLetters, props.deckMap));
        const wordsValid = words.map( (word) =>  isWordValid(word, props.wordList));
        const canLaydown = (props.lastTurn || props.handOrder.length <= 1) && (props.layingDownDiscard || props.handOrder.length == 1)  && (wordsValid.length == 0 || wordsValid.every((w) => !!w));
        return(
            <div>
                <Row>
                    <Col>
                        {props.layingDown.map( (laydownWord, wordI) =>
                            <Droppable key={wordI} droppableId={"laydown_" + wordI} direction="horizontal">
                                {(provided, snapshot) => (
                                    <div
                                        ref={provided.innerRef}
                                        className={wordsValid[wordI] ? "laydown-word-valid" : "laydown-word-invalid"}
                                        style={getListStyle(snapshot.isDraggingOver)}>
                                        {laydownWord.map((cI, index) =>
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
                                                        <ZCard card={props.deckMap[parseInt(cI)]}/>
                                                    </div>
                                                )}
                                            </Draggable>
                                        )}

                                        {provided.placeholder}
                                    </div>
                                )}
                            </Droppable>
                        )}

                        <Droppable droppableId='newLaydownWord' direction="horizontal">
                            {(provided, snapshot) => (
                                <div
                                    ref={provided.innerRef}
                                    style={getNewWordListStyle(snapshot.isDraggingOver)}>
                                    <div className="laydown-new-word">New Word</div>
                                    {provided.placeholder}
                                </div>
                            )}
                        </Droppable>
                    </Col>
                    <Col>
                        <Droppable droppableId='laydownDiscard' direction="horizontal" isDropDisabled={!!props.layingDownDiscard}>
                            {(provided, snapshot) => (
                                <div
                                    ref={provided.innerRef}
                                    style={getLaydownDiscardListStyle(snapshot.isDraggingOver)}>
                                    {!props.layingDownDiscard &&
                                    <div className="laydown-discard">Discard</div>
                                    }
                                    {props.layingDownDiscard &&
                                    <Draggable
                                        draggableId={props.layingDownDiscard.toString()}
                                        index={0}>
                                        {(provided, snapshot) => (
                                            <div
                                                ref={provided.innerRef}
                                                {...provided.draggableProps}
                                                {...provided.dragHandleProps}
                                                style={getItemStyle(
                                                    snapshot.isDragging,
                                                    provided.draggableProps.style
                                                )}>
                                                <ZCard card={props.deckMap[parseInt(props.layingDownDiscard)]}/>
                                            </div>
                                        )}
                                    </Draggable>
                                    }
                                    {provided.placeholder}
                                </div>
                            )}
                        </Droppable>
                        <Row>
                            <Button color="primary" disabled={!canLaydown} onClick={props.laydown}>Laydown</Button>
                            <Button onClick={props.cancelLaydown} className="mx-2">Cancel</Button>
                        </Row>
                    </Col>
                </Row>
                <LaydownTypeBox {...props} />
            </div>
        )
    }
}

function LaydownTypeBox(props) {
    const words = props.layingDown ?
        props.layingDown.map( (cardLetters) => cardsToWord(cardLetters, props.deckMap))
        : [""];

    return(
        <Input type="text" name="laydownTypeBox" id="laydownTypeBox"
               placeholder="laydown" autoComplete="false"
               value={words.join(" ")} onChange={props.laydownTypeBoxChange}
        />
    );
}

function LaydownDisplay(props) {
    return(
        <Row className='pl-1'>
            <Col md="auto">
                {props.laidDown.cards.map((wordCards, wordI) =>
                    <Row key={wordI}>
                        {wordCards.map((cI) =>
                            <ZCard key={cI} card={props.deckMap[parseInt(cI)]}/>
                        )}
                    </Row>
                )}
                {props.laidDown.leftover.length > 0 &&
                <Row className="laydown-word-leftover">
                    {props.laidDown.leftover.map((cI) =>
                        <ZCard key={cI} card={props.deckMap[parseInt(cI)]}/>
                    )}
                </Row>
                }
            </Col>
            <Col>
                Hand Score: {parseInt(props.laidDown.score)}
            </Col>
        </Row>
    );
}

// players hand + actions
class PlayerSpace extends React.Component {

    render() {
        const deckMap = this.props.game.deck;
        const tableState = this.props.game.table_state;
        const hand = this.props.handOrder.map(cI => parseInt(cI));
        const myTurn = this.props.player == this.props.game.table_state.active_player;
        const myPlay = myTurn && tableState.turn_state == "WAITING_TO_DISCARD";
        const isLayingDown = !!tableState.laying_down;
        const lastTurn = !$.isEmptyObject(this.props.game.table_state.laid_down);
        const canDiscard = myPlay && !this.props.layingDown && !lastTurn;
        const playStatus = this.props.playingTurnDing ? Sound.status.PLAYING : Sound.status.STOPPED;

        const myLaydownComplete = lastTurn && !$.isEmptyObject(this.props.game.table_state.laid_down[this.props.player]);

        let playerState  = "";
        if (myTurn) {
            if (tableState.turn_state == "WAITING_TO_DRAW") playerState = "Draw";
            if (tableState.turn_state == "WAITING_TO_DISCARD") playerState = "Discard or laydown";
            if (isLayingDown) playerState = "Discard/finish or cancel";
        }

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
            <span className={classNames('player-space', {'my-turn': myTurn})}>
                <div className="pl-1">
                    <div className="player-name">{this.props.player}</div>
                    <div className="player-score">Score: {parseInt(this.props.game.score[this.props.player])}</div>
                    {myTurn && <div className="player-state">{playerState}</div> }
                </div>
                {myTurn &&
                <Sound url={window.notificationPath} playStatus={playStatus} loop={false} onFinishedPlaying={this.props.turnDingDone}/>
                }

                {!myLaydownComplete &&
                <span>
                        <Col md={'auto'} className={classNames('mt-3', {'my-play': myPlay})}>
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
                    </span>
                }
                {myLaydownComplete &&
                <Col md='auto'>
                    <LaydownDisplay deckMap={deckMap} wordList={this.props.wordList}
                                    laidDown={this.props.game.table_state.laid_down[this.props.player]} />
                </Col>
                }
            </span>
        )
    }
}

function RoundSummary(props) {
    const tableState = props.game.table_state;
    const deckMap = props.game.deck;

    const players = props.game.players.sort((p1, p2) => props.game.score[p2] - props.game.score[p1]);
    const stats = props.game.stats;

    return(
        <Container>
            {players.map( (player) =>
                <Row key={player} className={classNames("player")}>
                    <div className="player-left col pl-1">
                        <div className="player-name">{player}</div>
                        <div className="player-score">Score: {parseInt(props.game.score[player])}</div>
                    </div>
                    <div className="player-right col">
                        <div className='cards-laydown cards-small'>
                            {tableState.laid_down[player].cards.map((wordCards, wordI) =>
                                <Row key={wordI}>
                                    {wordCards.map((cI) =>
                                        <ZCard key={cI} card={deckMap[parseInt(cI)]}/>
                                    )}
                                </Row>
                            )}
                            {tableState.laid_down[player].leftover.length > 0 &&
                            <Row className="laydown-word-leftover">
                                {tableState.laid_down[player].leftover.map((cI) =>
                                    <ZCard key={cI} card={deckMap[parseInt(cI)]}/>
                                )}
                            </Row>
                            }
                        </div>
                    </div>
                    <div className="col">
                        <div>Round Score: {parseInt(tableState.laid_down[player].score)}</div>
                        {tableState.laid_down[player].longest_word_bonus &&
                        <div className="longest-word-bonus">Longest Word Bonus</div>
                        }
                        {tableState.laid_down[player].most_words_bonus &&
                        <div className="most-words-bonus">Most Words Bonus</div>
                        }
                        {tableState.laid_down[player].word_smith_bonus &&
                        <div className="most-words-bonus">Word Smith Bonus (7+ letters!)</div>
                        }
                        {tableState.laid_down[player].bonus_words_score &&
                        <div className="bonus-words">Bonus Words ({tableState.laid_down[player].bonus_words}) +{parseInt(tableState.laid_down[player].bonus_words_score)}</div>
                        }
                    </div>
                </Row>
            )}
            <Row>
                {props.game.state != "GAME_OVER" &&
                <Button color="primary" onClick={props.startNextRound}>Start next round</Button>
                }
                {props.game.state == "GAME_OVER" &&
                <Button color="info" onClick={props.startNewGame}>Game Over! Start a new game</Button>
                }
            </Row>
            <Row>
                <div>
                    <h3>Fun Stats</h3>
                    <h4>Best Words</h4>
                    <ol>
                        {stats.best_words.map(x => x).splice(0, 3).map((best_word,i) =>
                            <li key={i}>{best_word[0]} : {best_word[1]} [score: {parseInt(best_word[2])}]</li>
                        )}
                    </ol>
                    <h4>Longest Words</h4>
                    <ol>
                        {stats.longest_words.map(x => x).splice(0, 3).map((w,i) =>
                            <li key={i}>{w[0]} : {w[1]} [letters: {parseInt(w[2])}]</li>
                        )}
                    </ol>

                    <h4>Most Words</h4>
                    <ol>
                        {stats.n_words.map((w,i) =>
                            <li key={i}>{w[0]} : {parseInt(w[1])} words</li>
                        )}
                    </ol>

                    <h4>Number of Leftover Letters</h4>
                    <ol>
                        {stats.leftover_letters.map((w,i) =>
                            <li key={i}>{w[0]} : {parseInt(w[1])} letters</li>
                        )}
                    </ol>
                </div>
            </Row>
        </Container>
    );
}

function ZCard(props) {
    // props.selectable
    return(
        <section className="card" value={props.card[0]} onClick={props.onClick}>
            <section className="card-number" value={props.card[1]} >
                <div className="card__inner card__inner--centered">
                    <div className="card__column">
                        <div className="card__symbol">{props.card[0]}</div>
                    </div>
                </div>
            </section>
        </section>
    );
}