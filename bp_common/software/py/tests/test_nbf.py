import importlib.util
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


script = Path(__file__).resolve().parents[1] / "nbf.py"
spec = importlib.util.spec_from_file_location("nbf", script)
nbf = importlib.util.module_from_spec(spec)
spec.loader.exec_module(nbf)


class NBFTest(unittest.TestCase):
    def converter(self, skip_zeros=False):
        converter = nbf.NBF(1, None, None, 1, None, False, skip_zeros,
                            64, None, False, False)
        converter.dram_data = {0x80000000: 0x0807060504030201,
                               0x80000008: 0}
        return converter

    def test_zero_initialization_covers_entire_memory_before_program(self):
        converter = self.converter()
        records = []
        converter.print_nbf = lambda *record: records.append(record)
        converter.init_dram()
        words = 1024 * 1024 // 8
        self.assertEqual(len(records), words + 2)
        for index, record in enumerate(records[:words]):
            self.assertEqual(record, (3, 0x80000000 + index * 8, 0))
        self.assertEqual(records[words:],
                         [(3, 0x80000000, 0x0807060504030201),
                          (3, 0x80000008, 0)])

    def test_skip_zeros_only_emits_nonzero_program_data(self):
        converter = self.converter(skip_zeros=True)
        records = []
        converter.print_nbf = lambda *record: records.append(record)
        converter.init_dram()
        self.assertEqual(records, [(3, 0x80000000, 0x0807060504030201)])

    def test_zero_sized_memory_still_emits_program_data(self):
        converter = self.converter()
        converter.mem_size = 0
        records = []
        converter.print_nbf = lambda *record: records.append(record)
        converter.init_dram()
        self.assertEqual(len(records), 2)
        self.assertEqual(records[0], (3, 0x80000000, 0x0807060504030201))

    def test_cli_loads_verilog_bytes_without_skip_zeros(self):
        with tempfile.TemporaryDirectory() as directory:
            memory = Path(directory) / "program.mem"
            memory.write_text("@00000000\n01 02 03 04 05 06 07 08\n")
            result = subprocess.run(
                [sys.executable, str(script), "--mem", str(memory),
                 "--mem_size", "1"], capture_output=True, text=True,
                timeout=15)
        self.assertEqual(result.returncode, 0, result.stderr)
        records = result.stdout.splitlines()
        self.assertIn("03_0000000080000000_0000000000000000", records)
        self.assertIn("03_00000000800ffff8_0000000000000000", records)
        self.assertIn("03_0000000080000000_0807060504030201", records)
        self.assertEqual(records[-1], "ff_0000000000000000_0000000000000000")


if __name__ == "__main__":
    unittest.main()
