"""Compatibility import for the complete primitive synthetic fixture.

The historical count-first generator is not imported or used. This module has
no empirical context factory and never selects a verifier from packet JSON.
"""
from synthetic_records import good_bundle, dumps, load_json, store_json, repin
