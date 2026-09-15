"""Public D547-PC1 adapter. Implementation is split by the existing proof boundary.

No derived-bit oracle remains in this entry point. Empirical authorization is an
out-of-band runner dependency; this library does not bind or certify anything.
"""
from admission_pipeline import (TrustedContext, EPOCH, ARMS, PANELS, VOWS,
    STRATA, PACKAGES, PAIRS, evaluate_packet, load_allocation, good_bundle,
    good_packet, _predicates, _rows_from_counts, _reason_result)
