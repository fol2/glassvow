"""Exercise the exact source-bound scope predicates that stopped before rows."""
import copy
import inspect
import textwrap
import unittest
import control


def scope(source, inherited, candidate):
    source_text=inspect.getsource(control.setup)
    start="    require(all(inherited[k]==candidate[k] for k in inherited if k!='cards'),'NONCARD_CONTENT_DELTA')"
    end="    template=load(repo/SHARED/'PROTOCOL.json')"
    assert source_text.count(start)==source_text.count(end)==1
    checks=textwrap.dedent(source_text[source_text.index(start):source_text.index(end)])
    exec(compile(checks,'actual_setup_scope','exec'),{'require':control.require,'source_content':source,
         'inherited':inherited,'candidate':candidate})


def fixtures():
    source={'cards':{'bloodRite':{'n':0},'leechBlade':{'n':0},'phantomBlades':{'rarity':'rare','n':3}},
            'statuses':{'burn':{'n':1}},'pools':['same']}
    inherited=copy.deepcopy(source)
    inherited['cards']['bloodRite']['n']=1;inherited['cards']['leechBlade']['n']=1
    inherited['statuses']['bloodfire']={'name':'bound source'}
    candidate=copy.deepcopy(inherited);candidate['cards']['phantomBlades']['n']=6
    return source,inherited,candidate


class StatusBindingTests(unittest.TestCase):
    def test_preexisting_bound_status_passes_while_old_predicate_failed(self):
        a,b,c=fixtures()
        self.assertFalse(all(a[k]==c[k] for k in a if k!='cards'))
        original=copy.deepcopy((a,b,c));scope(a,b,c);self.assertEqual((a,b,c),original)

    def test_wrong_bloodfire_definition_rejected(self):
        a,b,c=fixtures();c['statuses']['bloodfire']['name']='different'
        with self.assertRaisesRegex(ValueError,'NONCARD_CONTENT_DELTA'):scope(a,b,c)

    def test_unrelated_status_or_pool_rejected(self):
        for change in ('status','pool'):
            a,b,c=fixtures()
            if change=='status':c['statuses']['other']={}
            else:c['pools']=['different']
            with self.assertRaisesRegex(ValueError,'NONCARD_CONTENT_DELTA'):scope(a,b,c)

    def test_card_or_rarity_scope_rejected(self):
        a,b,c=fixtures();c['cards']['extra']={};a['cards']['extra']={}
        c['cards']['extra']['n']=7
        with self.assertRaisesRegex(ValueError,'ONLY_SELECTED_CONTENT'):scope(a,b,c)
        a,b,c=fixtures();c['cards']['phantomBlades']['rarity']='common'
        with self.assertRaisesRegex(ValueError,'RARITY'):scope(a,b,c)

if __name__=='__main__':unittest.main()
