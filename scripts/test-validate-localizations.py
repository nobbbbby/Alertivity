#!/usr/bin/env python3
"""Regressions for the format safety check used by CI."""
import importlib.util
import sys
import unittest
from pathlib import Path

sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('validator', Path(__file__).with_name('validate-localizations.py'))
validator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(validator)


class FormatArgumentsTests(unittest.TestCase):
    def test_reordering_preserves_argument_identity(self):
        self.assertEqual(validator.arguments('%d %@'), validator.arguments('%2$@ %1$d'))

    def test_type_changes_are_rejected(self):
        self.assertNotEqual(validator.arguments('%d %@'), validator.arguments('%@ %@'))

    def test_dropped_and_repeated_arguments_are_rejected(self):
        source = validator.arguments('%@ %@')
        self.assertNotEqual(source, validator.arguments('%@'))
        self.assertNotEqual(source, validator.arguments('%1$@ %1$@'))

    def test_width_precision_and_escaped_percent(self):
        self.assertEqual(validator.arguments('%1$08.2f %%'), validator.arguments('%% %1$f'))

    def test_integer_width_is_preserved(self):
        self.assertNotEqual(validator.arguments('%lld'), validator.arguments('%d'))

    def test_mixed_positioning_is_rejected(self):
        with self.assertRaises(ValueError):
            validator.arguments('%2$@ %@')

    def test_literal_percent_in_formatted_text_requires_escaping(self):
        with self.assertRaises(ValueError):
            validator.arguments('%@%', strict=True)
        self.assertEqual(validator.arguments('%@%%', strict=True), validator.arguments('%@'))

    def test_plain_text_percent_is_not_a_format_error(self):
        self.assertEqual(validator.arguments('1%–100%'), {})


if __name__ == '__main__':
    unittest.main()
