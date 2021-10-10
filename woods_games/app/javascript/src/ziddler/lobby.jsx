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
                <Row className="p-3  justify-content-center">
                    <Col md={6}>
                        {this.props.player
                            ? <StartGame startGame={this.props.startGame} />
                            : <PlayerInput addPlayer={this.props.addPlayer} requestState={this.props.requestState}/>
                        }
                    </Col>
                </Row>

                <Row className="justify-content-center">
                    <Col md={6}>
                        <PlayerList players={this.props.game.players} player={this.props.player}/>
                    </Col>
                </Row>

                <Row className="justify-content-center">
                    <Col md={6}>
                        { this.props.game.room && this.props.game.room != "NO_ROOM" && <p>
                            This Game is part of the {this.props.game.room} game room, anyone with access to the room can easily join from there.
                        </p>}
                        <p>
                            To invite players to join the game, simply send them the url of this page:
                        </p>
                        <input readOnly={true} id="game-url-copyarea" className="form-text text-muted url-copy-box" value={"http://ziddler.alexwoods.tech/games/" + window.gameId + "/play"} />
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
                <Row className="justify-content-center">
                    <Col md={6}>
                        <GameSettings settings={this.props.game.settings} updateSettings={this.props.updateSettings} requestState={this.props.requestState} />
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
            {player}
        </ListGroupItem>
    );

    return(
        <ListGroup>
            {props.player &&
            <ListGroupItem>
                <b>{props.player}</b>
            </ListGroupItem>}
            {playerItems}
        </ListGroup>
    );
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
                <h4>
                    Game settings:
                </h4>
                <Form>
                    <FormGroup check>
                        <Label check>
                            <Input type="checkbox" name="bonus_words" id="enable_bonus_words"
                                   checked={this.props.settings.enable_bonus_words}
                                   disabled={this.props.requestState == 'ACTING'}
                                   onChange={this.handleSubmit}
                            />
                            Bonus Words
                        </Label>
                    </FormGroup>
                    <FormGroup>
                        <Input type="select" name="wordList" id="wordListSelect"
                               value={this.props.settings.bonus_words}
                               disabled={!this.props.settings.enable_bonus_words}
                               onChange={(event) => {
                                   this.props.updateSettings({bonus_words: event.target.value});
                                   event.preventDefault();
                               }}
                        >
                            <option value={"animals_wordlist"}>Animals</option>
                            <option value={"foods_wordlist"}>Foods</option>
                            <option value={"holiday_wordlist"}>Holiday Words</option>
                        </Input>
                    </FormGroup>
                    <FormGroup check>
                        <Label check>
                            <Input type="checkbox" name="bonus_words" id="longest_word_bonus"
                                   checked={this.props.settings.longest_word_bonus}
                                   disabled={this.props.requestState == 'ACTING'}
                                   onChange={this.handleSubmit}
                            />
                            Longest Word Bonus
                        </Label>
                    </FormGroup>
                    <FormGroup check>
                        <Label check>
                            <Input type="checkbox" name="bonus_words" id="most_words_bonus"
                                   checked={this.props.settings.most_words_bonus}
                                   disabled={this.props.requestState == 'ACTING'}
                                   onChange={this.handleSubmit}
                            />
                            Most Words Bonus
                        </Label>
                    </FormGroup>
                    <FormGroup check>
                        <Label check>
                            <Input type="checkbox" name="bonus_words" id="word_smith_bonus"
                                   checked={this.props.settings.word_smith_bonus}
                                   disabled={this.props.requestState == 'ACTING'}
                                   onChange={this.handleSubmit}
                            />
                            Wordsmith Word Bonus
                        </Label>
                    </FormGroup>
                </Form>
            </div>
        )
    }
}