"""Predict one native linear-Hand hit, independently of the native implementation.
No game code is imported. This is not a whole-command or whole-run utility model.
"""
from __future__ import annotations
import copy


def need(ok, reason):
    if not ok:
        raise ValueError(reason)


def integer(value):
    need(type(value) is int, 'EXACT_INTEGER')
    return value


def hit(base, strength, weak, vulnerable, multiplier, block, hp, handoff=False):
    for x in (base, strength, multiplier, block, hp):
        integer(x)
    need(base >= 0 and multiplier in (1, 2) and block >= 0 and hp > 0, 'HIT_DOMAIN')
    need(type(weak) is bool and type(vulnerable) is bool and type(handoff) is bool, 'BOOLEAN_DOMAIN')
    damage = base + strength
    if weak:
        damage = damage * 3 // 4
    if vulnerable:
        damage = damage * 3 // 2
    damage = max(0, damage * multiplier)
    blocked = min(block, damage)
    loss = damage - blocked
    intercept = handoff and loss >= hp
    if intercept:
        loss = hp - 1
    next_hp = hp - loss
    return {'amount': loss, 'blocked': blocked, 'hpAfter': max(0, next_hp),
            'dead': not intercept and next_hp <= 0,
            'killingBlow': not intercept and next_hp <= 0 and loss > 0,
            'overkill': 0 if intercept else max(0, -next_hp)}


def features(before, command, coefficient):
    cb, run = before['combat'], before['run']
    need(command['t'] == 'playCard' and cb['over'] is False, 'LIVE_PLAY_ONLY')
    uid, target = integer(command['uid']), integer(command['target'])
    hand = cb['hand']
    need(len({integer(c['uid']) for c in hand}) == len(hand), 'UNIQUE_HAND')
    matches = [c for c in hand if c['uid'] == uid]
    need(len(matches) == 1 and matches[0]['id'] == 'phantomBlades', 'HAND_CONSUMER')
    enemies = [e for e in cb['enemies'] if e['idx'] == target]
    need(len(enemies) == 1 and integer(enemies[0]['hp']) > 0, 'LIVE_TARGET')
    e = enemies[0]
    attack_number = integer(cb['counters_attacks']) + 1
    relics = run['player']['relics']
    strength = integer(cb['player']['statuses'].get('str', 0))
    if 'ironTalisman' in relics and attack_number % 3 == 0:
        strength += 1
    mult = 2 if 'executionersSeal' in relics and attack_number % 10 == 0 else 1
    n = integer(coefficient)
    need(n in (0, 3, 4), 'LINEAR_HAND_COEFFICIENT_ONLY')
    return dict(base=n*(len(hand)-1), strength=strength,
                weak=integer(cb['player']['statuses'].get('weak', 0)) > 0,
                vulnerable=integer(e['statuses'].get('vulnerable', 0)) > 0,
                multiplier=mult, block=integer(e['block']), hp=integer(e['hp']),
                handoff=e['def'].get('finaleHandoff', False) is True)


def predict(before, command, coefficient):
    f = features(before, command, coefficient)
    return hit(**f)


def validate_record(row):
    steps = row['steps']
    need(len(steps) == 2 and all(s['ret'] is True for s in steps), 'TWO_LEGAL_COMMANDS')
    need(steps[0]['before'] == row['start'] and steps[0]['after'] == steps[1]['before']
         and steps[1]['after'] == row['end'], 'STATE_CONTINUITY')
    for s in steps:
        oldq, newq = s['before']['combat']['queue'], s['after']['combat']['queue']
        need(newq[:len(oldq)] == oldq and newq[len(oldq):] == s['events'], 'EVENT_BINDING')
        need(s['ret'] is s['after']['return'], 'RETURN_BINDING')
    consumer = steps[1]
    n = (4 if row['up'] else 3) if row['world'] in ('11', 'reference') or row['world'] == '01' else 0
    predicted = predict(consumer['before'], consumer['command'], n)
    events = [e for e in consumer['events'] if e.get('t') == 'hitEnemy']
    need(len(events) >= 1, 'NATIVE_HIT_MISSING')
    actual = events[0]
    need(actual['idx'] == consumer['command']['target'], 'HIT_TARGET')
    need(all(type(actual[k]) is type(v) and actual[k] == v for k, v in predicted.items()), 'PREDICTED_NATIVE_HIT')
    useful = features(consumer['before'], consumer['command'], n)['hp'] - actual['hpAfter']
    need(useful == min(features(consumer['before'],consumer['command'],n)['hp'], predicted['amount']), 'USEFUL_HP_NOT_RAW_HIT')
    return {'prediction':predicted,'useful_hp_removed':useful,
            'player_hp_delta':consumer['after']['combat']['player']['hp']-consumer['before']['combat']['player']['hp'],
            'downstream_events_retained':len(consumer['events'])-len(events)}
