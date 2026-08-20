'use strict';

const crypto = require('crypto');

const COLORS = ['blue', 'red', 'yellow', 'green', 'purple', 'orange', 'pink'];

function deckConfig(playerCount) {
    if (playerCount >= 2 && playerCount <= 4) return { colors: COLORS.slice(0, 4), deckSize: 40 };
    if (playerCount >= 5 && playerCount <= 6) return { colors: COLORS.slice(0, 5), deckSize: 50 };
    if (playerCount >= 7 && playerCount <= 8) return { colors: COLORS.slice(0, 6), deckSize: 60 };
    if (playerCount >= 9 && playerCount <= 10) return { colors: COLORS.slice(0, 7), deckSize: 70 };
    throw new Error('Oyuncu sayisi 2-10 arasinda olmali.');
}

function createDeck(playerCount) {
    const { colors, deckSize } = deckConfig(playerCount);
    const cards = [];
    while (cards.length < deckSize) {
        for (const color of colors) {
            for (let number = 1; number <= 10 && cards.length < deckSize; number += 1) {
                cards.push({ id: crypto.randomUUID(), color, number });
            }
        }
    }
    return cards;
}

function shuffle(cards, randomBytes = crypto.randomBytes) {
    const result = cards.slice();
    for (let i = result.length - 1; i > 0; i -= 1) {
        const limit = Math.floor(0x100000000 / (i + 1)) * (i + 1);
        let value;
        do { value = randomBytes(4).readUInt32BE(0); } while (value >= limit);
        const j = value % (i + 1);
        [result[i], result[j]] = [result[j], result[i]];
    }
    return result;
}

function bestHand(cards) {
    if (!Array.isArray(cards) || cards.length === 0) return { score: 0, type: null, value: null, cards: [] };
    const groups = [];
    const colors = new Map();
    const numbers = new Map();
    for (const card of cards) {
        colors.set(card.color, [...(colors.get(card.color) || []), card]);
        numbers.set(card.number, [...(numbers.get(card.number) || []), card]);
    }
    for (const [value, groupCards] of colors) {
        groups.push({ score: groupCards.reduce((sum, card) => sum + card.number, 0), type: 'color', value, cards: groupCards });
    }
    for (const [value, groupCards] of numbers) {
        groups.push({ score: groupCards.reduce((sum, card) => sum + card.number, 0), type: 'number', value, cards: groupCards });
    }
    groups.sort((a, b) => b.score - a.score || b.cards.length - a.cards.length || (a.type === 'color' ? -1 : 1));
    return groups[0];
}

function scoreHand(cards) { return bestHand(cards).score; }

module.exports = { COLORS, deckConfig, createDeck, shuffle, bestHand, scoreHand };
