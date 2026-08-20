'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { createDeck, deckConfig, bestHand, scoreHand } = require('../games/kart_zil_engine');

test('deck configuration follows player bands', () => {
    assert.deepEqual(deckConfig(2), { colors: ['blue', 'red', 'yellow', 'green'], deckSize: 40 });
    assert.equal(createDeck(2).length, 40);
    assert.equal(createDeck(3).length, 40);
    assert.equal(createDeck(4).length, 40);
    assert.equal(createDeck(5).length, 50);
    assert.equal(createDeck(6).length, 50);
    assert.equal(createDeck(7).length, 60);
    assert.equal(createDeck(8).length, 60);
    assert.equal(createDeck(9).length, 70);
    assert.equal(createDeck(10).length, 70);
    assert.equal(deckConfig(10).colors.length, 7);
    assert.throws(() => createDeck(1));
    assert.throws(() => createDeck(11));
});

test('every card has a unique server id', () => {
    const deck = createDeck(10);
    assert.equal(new Set(deck.map(card => card.id)).size, deck.length);
});

test('score selects the best color or number group only', () => {
    assert.equal(scoreHand([
        { color: 'blue', number: 2 }, { color: 'blue', number: 9 },
        { color: 'yellow', number: 4 }, { color: 'red', number: 10 }
    ]), 11);
    assert.equal(scoreHand([
        { color: 'blue', number: 7 }, { color: 'red', number: 7 },
        { color: 'yellow', number: 3 }, { color: 'green', number: 9 }
    ]), 14);
    assert.equal(scoreHand([
        { color: 'red', number: 10 }, { color: 'yellow', number: 10 },
        { color: 'green', number: 3 }, { color: 'blue', number: 2 }
    ]), 20);
    assert.equal(scoreHand([
        { color: 'blue', number: 3 }, { color: 'blue', number: 4 },
        { color: 'red', number: 4 }, { color: 'green', number: 8 }
    ]), 8);
});

test('best hand reveals only the cards that produce the score', () => {
    const cards = [
        { id: 'a', color: 'blue', number: 7 },
        { id: 'b', color: 'red', number: 7 },
        { id: 'c', color: 'yellow', number: 3 },
        { id: 'd', color: 'green', number: 9 }
    ];
    const best = bestHand(cards);
    assert.equal(best.score, 14);
    assert.equal(best.type, 'number');
    assert.deepEqual(best.cards.map(card => card.id), ['a', 'b']);
});
