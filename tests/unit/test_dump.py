import pytest

from git.dump import DumpType

@pytest.mark.parametrize("input, expected", [
    ('Default', DumpType.Default),
    ('Header', DumpType.Header),
    ('Custom', DumpType.Custom)
])
def test_dump_type_generation(input, expected):
    result = DumpType.from_string(input)
    assert expected == result

@pytest.mark.parametrize("input, expected", [
    (DumpType.Default, 'Default'),
    (DumpType.Header, 'Header'),
    (DumpType.Custom, 'Custom')
])
def test_dump_type_stringify(input, expected):
    result = str(input)
    assert expected == result
