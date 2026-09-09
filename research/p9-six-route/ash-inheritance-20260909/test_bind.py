import unittest
import bind

class BindingTests(unittest.TestCase):
    def test_historical_python_is_not_executed(self):
        x=bind.relevant_python(b"raise RuntimeError('no execution')\ndef make():\n    return {'bloodfire': 1}\n")
        self.assertIn('make',x)
    def test_unrelated_source_is_not_selected(self):
        self.assertEqual(bind.relevant_python(b'def unrelated():\n    return 1\n'),{})
    def test_duplicate_gd_function_rejected(self):
        with self.assertRaisesRegex(ValueError,'DUPLICATE'):
            bind.gd_functions('func x():\n pass\nfunc x():\n pass\n')
    def test_status_is_not_inferred_from_card_effect(self):
        self.assertEqual(bind.status_object({'cards':{'x':{'bloodfire':1}}}),{})
    def test_real_status_definition_is_preserved(self):
        self.assertEqual(bind.status_object({'statuses':{'bloodfire':{'name':'Bloodfire'}}}),{'statuses/bloodfire':{'name':'Bloodfire'}})
    def test_serialisation_does_not_depend_on_dict_insertion(self):
        self.assertEqual(bind.dump({'a':1,'b':2}),bind.dump({'b':2,'a':1}))

if __name__=='__main__':unittest.main()
