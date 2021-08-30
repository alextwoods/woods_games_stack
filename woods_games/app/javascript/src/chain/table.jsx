import React from 'react'
import ReactDOM from 'react-dom'
import PropTypes from 'prop-types'
import {Container, Row, Col, Input, FormGroup} from 'reactstrap';
import { Button } from 'reactstrap';
import Sound from 'react-sound';

var classNames = require('classnames');

// port functionality from ruby deck/board classes to functions here
const suitS = ["H", "S", "D", "C"];

// one eyed jacks, hearts and spades
const isAntiWild = (card) => card.number == 11 && (card.suit == "H" || card.suit == "S")

// two eyed jacks, Diamonds and Clubs
const isWild = (card) => card.number == 11 && (card.suit == "D" || card.suit == "C")

const cardNumToDisplay = (num) => {
    const map = {
        1: 'A',
        2: 2,
        3: 3,
        4: 4,
        5: 5,
        6: 6,
        7: 7,
        8: 8,
        9: 9,
        10: 10,
        11: 'J',
        12: 'Q',
        13: 'K'
    }
    return( map[num] )
}

const cIToCard = (cI) => {
    const i = parseInt(cI) % 52 // divide two decks into 2 of 52 cards
    const suit = suitS[Math.floor(i / 13)] // divide deck into 4 suits of 13 cards each
    const number = (i % 13) + 1 // get the card number (add 1 to fix zero index)
    return {suit: suit, number: number}
}

const stoCard = (s) => {
    const m = s.match(/(\d+)([HSDC])/);
    if (m){
        return {suit: m[2], number: m[1]};
    } else {
        return null;
    }
}

const buildSequenceSet = (teamSequences) => {
    const set = {};
    teamSequences = new Map(Object.entries(teamSequences));
    teamSequences.forEach( (sequences, team) => {
        sequences.forEach( (sequence) => sequence.forEach( (bI) => set[parseInt(bI)] = team))
    })
    return(set);
}


export default class Table extends React.Component {

    render() {

        const sequenceSet = buildSequenceSet(this.props.game.table_state.board.sequences);

        const players = this.props.game.players.map(player =>
            <Player key={player} player={player} isSelf={player == this.props.player} game={this.props.game}/>
        );
        return (
            <Container style={{maxWidth: '1200px'}}>
                <Row className="mt-3">
                    <Col md={3}>
                        {players}
                        <GameLog log={this.props.game.table_state.log} />
                    </Col>
                    <Col xs="auto">
                        <Board game={this.props.game} player={this.props.player}
                               selectedCard={this.props.selectedCard}
                               sequenceSet={sequenceSet}
                               isSelectedCardClicked={this.props.isSelectedCardClicked}
                               playCard={this.props.playCard}
                        />
                    </Col>
                </Row>
                <Row>
                    {/* Use key to force a full re-render when the active player changes*/}
                    <PlayerSpace game={this.props.game} player={this.props.player}
                                 key={this.props.game.table_state.turn}
                                 cardHovered={this.props.cardHovered}
                                 cardClicked={this.props.cardClicked}
                                 selectedCard={this.props.selectedCard}
                                 playingTurnDing={this.props.playingTurnDing}
                                 turnDingDone={this.props.turnDingDone}
                    />
                </Row>

                {this.props.game.table_state.state == 'GAME_OVER' &&
                <div className="game-over-overlay">
                    <div className="d-flex justify-content-center winner-banner">
                        {this.props.game.table_state.winne == 'DRAW' ? 'DRAW' : this.props.game.table_state.winner + ' WINS!'}
                    </div>
                    <div className="d-flex justify-content-center">
                        <Button color="primary" onClick={this.props.rematch}>
                            Rematch
                        </Button>
                        <Button color="primary" className={"ml-5"} onClick={this.props.startNewGame}>
                            New Game
                        </Button>
                    </div>
                    { this.props.game.room && this.props.game.room != "NO_ROOM" && <div className="d-flex justify-content-center my-3">
                        <a href={"/rooms/" + this.props.game.room}>Return to {this.props.game.room} game room</a>
                    </div>}
                </div>
                }

            </Container>
        );
    }
}

function Player(props) {
    const player = props.player;
    const tableState = props.game.table_state;
    const deckMap = props.game.deck;
    const isActivePlayer = player == tableState.active_player;
    const isCpu = props.game.cpu_players.includes(player);
    const team = props.game.player_team[player];

    return(
        <Row className={classNames({"active-player": isActivePlayer}, "player", team + "-team-player")}>
            <div className="player-left pl-1">
                <div className={classNames({"self-player": props.isSelf, "cpu-player": isCpu}, "player-name")}>{props.player}</div>
                {isCpu &&
                <span>(CPU)</span>
                }
                {isActivePlayer &&
                <span className="player-state">ACTIVE</span>
                }
            </div>
        </Row>
    );
}

function GameLog(props) {
    const logs = props.log.slice(0).reverse();
    const logEntries = logs.map( (e, i) =>
        <LogEntry entry={e} key={i}/>
    );
    return(
        <div className={"log-wrapper"}>
            <ul className={"game-log-list"}>
                {logEntries}
            </ul>
        </div>
    );
}

function LogEntry(props) {
    const e = props.entry;
    const card = cIToCard(e.cardI);
    return(
        <li>
            {e.player}({e.team}) played <DisplayCard card={card} /> on {parseInt(e.row)},{parseInt(e.col)}
        </li>
    );
}

// Board
function Board(props) {
    const tableState = props.game.table_state;
    const board = tableState.board;
    const myTurn = props.player == tableState.active_player;

    var rows = [];
    for(var rI =0; rI < 10; rI++) {
        var cols = [];
        for(var cI = 0; cI < 10; cI++) {
            const boardI = rI*10 + cI;
            cols.push(
                <BoardCard board={board} boardI={boardI} key={boardI}
                           playerTeam={props.game.player_team[props.player]}
                           sequenceSet={props.sequenceSet}
                           selectedCard={props.selectedCard}
                           isSelectedCardClicked={props.isSelectedCardClicked}
                           playCard={props.playCard}
                />
            );
        }
        rows.push(
            <tr className={"board-row"} key={rI}>
                {cols}
            </tr>
        )
    }
    return(
        <div>
            <table className={"board"}>
                <tbody>
                {rows}
                </tbody>
            </table>
        </div>
    )
}

function BoardFreeSpace(props) {
    const f  = "\u2609";
    return(
        <span>{f}</span>
    );
}

function BoardCard(props) {

    const cardText = props.board.board[props.boardI];
    const token = props.board.tokens[props.boardI];
    const tokenClass = "board-token-" + token;

    const spaceCard = stoCard(cardText);

    let isSelected = false;
    if (spaceCard && props.selectedCard) {
        const selectedCard = cIToCard(props.selectedCard);

        if (!token) {
            isSelected = (isWild(selectedCard)) || (spaceCard.suit == selectedCard.suit && spaceCard.number == selectedCard.number);
        } else if (isAntiWild(selectedCard)) {
            isSelected = props.playerTeam != token && !props.sequenceSet[props.boardI];  // TODO: check  not sequence
        }
    }

    const cardInner = cardText === "F" ? <BoardFreeSpace /> : <DisplayCard card={spaceCard} />

    let classes = {"selected-board-card": isSelected, "board-token": !!token, "board-card-sequence": !!props.sequenceSet[props.boardI]}
    classes[tokenClass] = !!token;
    classes["board-free-space"] = cardText === "F";
    classes["board-card-sequence-" + props.sequenceSet[props.boardI]] = !!props.sequenceSet[props.boardI];
    return(
        <td className={classNames("board-card", classes)}
            onClick={(event => {
                if (isSelected && props.isSelectedCardClicked) {
                    props.playCard(props.selectedCard, props.boardI);
                }
            })}
        >
            {cardInner}
        </td>
    );
}

// players hand + actions
class PlayerSpace extends React.Component {

    render() {
        const tableState = this.props.game.table_state;
        const myTurn = this.props.player == this.props.game.table_state.active_player;
        const hand = tableState.hands[this.props.player]
        const playStatus = this.props.playingTurnDing ? Sound.status.PLAYING : Sound.status.STOPPED;

        const handCards = hand.map((cI, index) =>
            <Card card={cI} key={cI} cardHovered={this.props.cardHovered} cardClicked={this.props.cardClicked} selectedCard={this.props.selectedCard}/>
        );
        return (
            <span className={classNames('player-space', {'my-turn': myTurn})}>
                <div className="pl-1">
                    <div className="player-name">{this.props.player}</div>
                </div>
                {myTurn &&
                <Sound url={window.notificationPath} playStatus={playStatus} loop={false} onFinishedPlaying={this.props.turnDingDone}/>
                }
                <div className="hand-cards">
                    {handCards}
                </div>
            </span>
        );
    }

}

function CardSuit(props) {
    const suitMap = {
        "H": "\u2665",
        "S": "\u2660",
        "D": "\u2666",
        "C": "\u2663"
    }
    return(
        <span className={"card-suit-" + props.suit}>
            {suitMap[props.suit]}
        </span>
    )
}

function DisplayCard(props) {
    const card = props.card;
    // handle jacks
    if (isAntiWild(card)) {
        return(
            <span title="remove">
                {"\u2606"}
            </span>
        );
    } else if (isWild(card)) {
        return(
            <span title="wild">
              {"\u2605"}
          </span>
        )
    } else {
        return (
            <span>
            {cardNumToDisplay(card.number)}<CardSuit suit={card.suit}/>
        </span>
        );
    }
}

function Card(props) {
    // props.selectable
    const card = cIToCard(props.card);
    return(
        <div className={classNames("hand-card", {"hand-card-selected": props.selectedCard == props.card})}
             onMouseEnter={() => props.cardHovered(props.card)}
             onMouseLeave={() => props.cardHovered(null)}
             onMouseUp={() => props.cardClicked(props.card)}
        >
            <DisplayCard card={card} />
        </div>
    );
}