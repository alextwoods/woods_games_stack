import React from 'react'
import ReactDOM from 'react-dom'
import PropTypes from 'prop-types'
import { Container, Row, Col } from 'reactstrap';
import { Button, Form, FormGroup, Label, Input } from 'reactstrap';
import { ListGroup, ListGroupItem } from 'reactstrap';

export default class Lobby extends React.Component {

    render() {
        return (
            <Container>
                <Row className="justify-content-center">
                    <Col md={6}>
                        {this.props.player
                            ? <AddCpuPlayer addCpuPlayer={this.props.addCpuPlayer}/>
                            : <PlayerInput addPlayer={this.props.addPlayer} requestState={this.props.requestState}/>
                        }
                    </Col>
                </Row>

                <Row className="justify-content-center">
                    <Col md={6}>
                        <PlayerList players={this.props.game.players} cpuPlayers={this.props.game.cpu_players} playerTeams={this.props.game.player_team} player={this.props.player} updatePlayerTeam={this.props.updatePlayerTeam}/>
                    </Col>
                </Row>

                { this.props.game.players.length >= 2 &&
                <Row>
                    <Col md={6}>
                        <StartGame startGame={this.props.startGame}/>
                    </Col>
                </Row>
                }

                <Row className="justify-content-center">
                    <Col md={6}>
                        <GameSettings settings={this.props.game.settings} updateSettings={this.props.updateSettings} requestState={this.props.requestState} />
                    </Col>
                </Row>


                <Row className="justify-content-center">
                    <Col md={6}>
                        <hr/>
                        <h4>
                            Invite Others
                        </h4>
                        { this.props.game.room && this.props.game.room != "NO_ROOM" && <p>
                            This Game is part of the {this.props.game.room} game room, anyone with access to the room can easily join from there.
                        </p>}
                        <p>
                            To invite players to join the game, simply send them the url of this page:
                        </p>
                        <input readOnly={true} id="game-url-copyarea" className="form-text text-muted url-copy-box" value={"http://chain.alexwoods.tech/games/" + window.gameId + "/play"} />
                        <Button color="primary" onClick={function() {
                            let copyTextarea = document.querySelector("#game-url-copyarea");
                            copyTextarea.focus();
                            copyTextarea.select();

                            try {
                                var successful = document.execCommand('copy');
                                var msg = successful ? 'successful' : 'unsuccessful';
                                console.log('Copying text command was ' + msg);
                            } catch (err) {
                                console.log('Oops, unable to copy');
                            }
                        }}>
                            Copy
                        </Button>
                    </Col>
                </Row>

            </Container>
        );
    }
}

class PlayerInput extends React.Component {

    constructor(props) {
        super(props);
        this.state = {value: ''};
        this.handleChange = this.handleChange.bind(this);
        this.handleSubmit = this.handleSubmit.bind(this);
    }

    handleChange(event) {    this.setState({value: event.target.value});  }

    handleSubmit(event) {
        this.props.addPlayer(this.state.value);
        event.preventDefault();
    }

    render() {
        return (
            <Form onSubmit={this.handleSubmit} inline>
                <FormGroup>
                    <Label for="playerName" hidden>Name</Label>
                    <Input type="text" name="name" id="playerName"
                           placeholder="Nick Name" autoComplete="false"
                           value={this.state.value} onChange={this.handleChange}
                           disabled={this.props.requestState == 'ACTING'}
                    />
                </FormGroup>
                <Button color="primary" type="submit" disabled={this.props.requestState == 'ACTING'}>
                    Submit
                </Button>
            </Form>
        )
    }
}


function AddCpuPlayer(props) {
    return(
        <Button color="primary" onClick={props.addCpuPlayer}>
            Add CPU Player
        </Button>
    )
}

function StartGame(props) {
    return(
        <Button color="primary" onClick={props.startGame}>
            Start Game
        </Button>
    )
}

function PlayerList(props) {
    const otherPlayers =  props.players.filter( p => p != props.player );
    const playerItems = otherPlayers.map (player =>
        <ListGroupItem key={player}>
            <PlayerDisplay player={player} isSelf={false} isCpu={props.cpuPlayers.includes(player)} team={props.playerTeams[player]} updatePlayerTeam={props.updatePlayerTeam} />
        </ListGroupItem>
    );

    return(
        <ListGroup className="p-2">
            {props.player &&
            <ListGroupItem>
                <PlayerDisplay player={props.player} isSelf={true} isCpu={false} team={props.playerTeams[props.player]} updatePlayerTeam={props.updatePlayerTeam} />
            </ListGroupItem>}
            {playerItems}
        </ListGroup>
    );
}

function PlayerDisplay(props) {
    return(
        <span>
            {props.isSelf ? <b>{props.player}</b> : props.player }
            {props.isCpu ? " (CPU)" : "" }
            <Input type="select" name="boardList" id="boardListSelector"
                   value={props.team}
                   onChange={(event) => {
                       props.updatePlayerTeam({player: props.player, team: event.target.value});
                       event.preventDefault();
                   }}
            >
                <option value="green">Green</option>
                <option value="blue">Blue</option>
                <option value="red">Red</option>
            </Input>
        </span>
    )
}

Lobby.propTypes = {
    game: PropTypes.object,
    player: PropTypes.string
}

class GameSettings extends React.Component {

    constructor(props) {
        super(props);
        this.handleSubmit = this.handleSubmit.bind(this);
    }

    handleSubmit(event) {
        let data = {}
        data[event.target.id] = event.target.checked;
        this.props.updateSettings(data);
        event.preventDefault();
    }

    render() {
        return (
            <div>
                <hr/>
                <h4>
                    Game settings:
                </h4>
                <Form>
                    <FormGroup>
                        <Label for="boardListSelector">Board Layout</Label>
                        <Input type="select" name="boardList" id="boardListSelector"
                               value={this.props.settings.board}
                               onChange={(event) => {
                                   this.props.updateSettings({board: event.target.value});
                                   event.preventDefault();
                               }}
                        >
                            <option value={"spiral"}>Spiral</option>
                            <option value={"horizontal"}>Horizontal</option>
                        </Input>
                    </FormGroup>
                    <FormGroup>
                        <Label for="sequenceLength">Sequence Length</Label>
                        <Input type="number" min="3" max="10" id="sequenceLength"
                               value={this.props.settings.sequence_length}
                               onChange={(event) => {
                                   this.props.updateSettings({sequence_length: event.target.value});
                                   event.preventDefault();
                               }}
                        />
                    </FormGroup>
                    <FormGroup>
                        <Label for="sequencesToWin">Sequence To Win</Label>
                        <Input type="number" min="1" max="10" id="sequencesToWin"
                               value={this.props.settings.sequences_to_win}
                               onChange={(event) => {
                                   this.props.updateSettings({sequences_to_win: event.target.value});
                                   event.preventDefault();
                               }}
                        />
                    </FormGroup>
                </Form>
            </div>
        )
    }
}