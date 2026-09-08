"""GPU evidence must not sum concurrent channels, nested work or other processes."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
import xml.etree.ElementTree as ET

SPEC = importlib.util.spec_from_file_location('metal_summary', Path(__file__).resolve().parents[1] / 'tools/map_workshop/common/summarise_metal_trace.py')
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class MetalSummaryTest(unittest.TestCase):
    def test_active_interval_union(self):
        root = ET.Element('trace-query-result')
        for frame in range(1, 35):
            for start, duration, pid in [(0, 2_000_000, 42), (1_000_000, 2_000_000, 42),
                                         (500_000, 500_000, 42), (0, 9_000_000, 43)]:
                row = ET.SubElement(root, 'row')
                for tag, text in [('start-time', frame*10_000_000+start), ('duration', duration),
                                  ('gpu-channel-name', 'Fragment'), ('gpu-frame-number', frame),
                                  ('duration', 0), ('metal-nesting-level', 0), ('label', 'work'),
                                  ('gpu-state', 'Active'), ('connection', 0), ('colour', 0)]:
                    ET.SubElement(row, tag).text = str(text)
                ET.SubElement(row, 'process', fmt=f'godot ({pid})')
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'intervals.xml'
            ET.ElementTree(root).write(path)
            report = MODULE.summarise(path, 42)
            self.assertEqual(report['frames'], 32)
            self.assertEqual(report['active_gpu_ms']['max'], 3.0)
            with self.assertRaises(ValueError):
                MODULE.summarise(path, 99)


if __name__ == '__main__':
    unittest.main()
