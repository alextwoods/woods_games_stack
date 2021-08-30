import React from 'react'
import ReactDOM from 'react-dom'
import PropTypes from 'prop-types'
import 'jquery'
import { Toast, ToastBody, ToastHeader, Spinner } from 'reactstrap';

import Lobby from '../src/chain/lobby'

import Cookies from 'js-cookie'
import Table from "../src/chain/table";

import 'bootstrap/dist/css/bootstrap.min.css';
import "../stylesheets/chain/game.css"
import "../stylesheets/chain/cards.css"

class ChainGame extends React.Component {

    constructor(props) {
        super(props);

        this.player_cookie = "player_" + props.gameId;

        this.state = {
            requestState: 'NONE',
            game: null,
            player: null,
            toast: null,
            playingTurnDing: false,
            selectedCard: null,
            isSelectedCardClicked: false,
        };

        this.onAjaxError = this.onAjaxError.bind(this);
        this.refreshGameData = this.refreshGameData.bind(this);
        this.addPlayer = this.addPlayer.bind(this);
        this.addCpuPlayer = this.addCpuPlayer.bind(this);
        this.updatePlayerTeam = this.updatePlayerTeam.bind(this);
        this.updateSettings = this.updateSettings.bind(this);
        this.startGame = this.startGame.bind(this);
        this.dismissToast = this.dismissToast.bind(this);
        this.turnDingDone = this.turnDingDone.bind(this);

        this.cardHovered = this.cardHovered.bind(this);
        this.cardClicked = this.cardClicked.bind(this);
        this.playCard = this.playCard.bind(this);

        this.startNewGame = this.startNewGame.bind(this);
        this.rematch = this.rematch.bind(this);
    }

    componentDidMount() {
        console.log("Mounted.  Kicking off first state load");

        this.refreshGameData();
        this.interval = setInterval(this.refreshGameData, 1000);
    }

    componentWillUnmount() {
        clearInterval(this.interval);
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
                    this.setState({requestState: 'NONE', game: game, player: player});
                },
                error: this.onAjaxError
            });
        } else {
            console.log("Skipping update.  State: ", this.state.requestState);
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


    addCpuPlayer() {
        if (this.state.requestState == "ACTING") {
            console.warn("Action already in progress.  Skipping");
            return;
        }

        this.setState({requestState: 'ACTING'} )

        $.ajax({
            url: this.props.gamePath + "/cpu",
            type: 'POST',
            success: (response) => {
                this.setState({requestState: 'NONE', game: response.data})
            },
            error: this.onAjaxError
        });
    }

    updatePlayerTeam(player, team) {
        if (this.state.requestState == "ACTING") {
            console.warn("Action already in progress.  Skipping");
            return;
        }

        this.setState({requestState: 'ACTING'} )

        $.ajax({
            url: this.props.gamePath + "/player_team",
            type: 'POST',
            data: {player: player, team: team},
            success: (response) => {
                this.setState({requestState: 'NONE', game: response.data})
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
            data: {settings: settings},
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

    startNewGame() {
        this.setState({requestState: 'ACTING'} )

        $.ajax({
            url: this.props.gamePath + "/newgame",
            type: 'POST',
            success: (response) => this.setState({requestState: 'NONE', game: response.data}),
            error: this.onAjaxError
        });
    }

    rematch() {
        this.setState({requestState: 'ACTING'} )

        $.ajax({
            url: this.props.gamePath + "/rematch",
            type: 'POST',
            success: (response) => this.setState({requestState: 'NONE', game: response.data}),
            error: this.onAjaxError
        });
    }

    cardHovered(cardI) {
        // if a card has been clicked, ignore it.
        if (!this.state.isSelectedCardClicked) {
            this.setState({selectedCard: cardI, isSelectedCardClicked: false});
        }
    }

    cardClicked(cardI) {
        // https://dev.to/vibhanshu909/click-outside-listener-for-react-components-in-10-lines-of-code-4gjo
        if (this.state.player == this.state.game.table_state.active_player ) {
            this.setState({selectedCard: cardI, isSelectedCardClicked: true});
        }
    }

    playCard(cardI, boardI) {
        if (this.state.player == this.state.game.table_state.active_player ) {
            if (this.state.requestState == "ACTING") {
                console.warn("Action already in progress.  Skipping");
                return;
            }

            this.setState({requestState: 'ACTING'} )

            $.ajax({
                url: this.props.gamePath + "/play_card",
                type: 'POST',
                data: {play: {cardI: cardI, boardI: boardI}},
                success: (response) => {
                    this.setState({requestState: 'NONE', game: response.data,
                        selectedCard: null, isSelectedCardClicked: false})
                },
                error: this.onAjaxError
            });
        }
    }

    turnDingDone() {
        this.setState({playingTurnDing: false});
    }


    dismissToast() {
        this.setState({toast: null});
    }

    render() {
        return(
            <div>
                {this.state.game
                    ? <Game game={this.state.game} player={this.state.player}
                            toast={this.state.toast}
                            requestState={this.state.requestState}
                            playingTurnDing={this.state.playingTurnDing}
                            addPlayer={this.addPlayer}
                            addCpuPlayer={this.addCpuPlayer}
                            updatePlayerTeam={this.updatePlayerTeam}
                            updateSettings={this.updateSettings}
                            startGame={this.startGame}
                            cardHovered={this.cardHovered}
                            cardClicked={this.cardClicked}
                            playCard={this.playCard}
                            selectedCard={this.state.selectedCard}
                            isSelectedCardClicked={this.state.isSelectedCardClicked}
                            dismissToast ={this.dismissToast}
                            turnDingDone={this.turnDingDone}
                            startNewGame={this.startNewGame}
                            rematch={this.rematch}
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
ChainGame.propTypes = {
    gameId: PropTypes.string,
    gamePath: PropTypes.string
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
        <ChainGame gameId={window.gameId} gamePath={window.gamePath}/>,
        document.body.appendChild(document.createElement('div')),
    )
})