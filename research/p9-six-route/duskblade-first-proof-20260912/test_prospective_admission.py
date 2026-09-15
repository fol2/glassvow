"""Discover the complete active R1-R3 suite; historical probes are not imported."""
import unittest
from synthetic_controls import (EntryTests, PrimitiveTests, NumericalEntryTests,
                                ModelTests, LoadBearingTests)
from boundary_controls import BoundaryRecordTests, ReceiptTests
from allocation_controls import AllocationRecordTests

if __name__ == '__main__':
    unittest.main(verbosity=2)
