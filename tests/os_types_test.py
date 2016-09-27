import pytest

from git.os_types import generate_os_types, short_os_type_name

@pytest.mark.parametrize("input, expected", [
    ("Windows", ['win']),
    ("windows", ['win']),
    ("win", ['win']),
    ("win", ['win']),
    ("Darwin", ['mac']),
    ("darwin", ['mac']),
    ("Mac", ['mac']),
    ("mac", ['mac']),
    ("Windows, Mac", ['win', 'mac']),
    ("Windows, Darwin", ['win', 'mac']),
    ("Windows, Mac, iOS", ['win', 'mac', 'ios']),
    ("Windows, Mac, Android", ['win', 'mac', 'android']),
    ("Windows, Mac, Android, Other", ['win', 'mac', 'android', 'other'])
])

def test_os_type_generation(input, expected):
    result = generate_os_types(input)
    assert set(result) == set(expected)

@pytest.mark.parametrize("input, expected", [
    ('Windows', 'win'),
    ('windows', 'win'),
    ('Darwin', 'mac'),
    ('darwin', 'mac'),
    ('Other', 'other'),
    ('other', 'other')
])
def test_os_name_shorting(input, expected):
    result = short_os_type_name(input)
    assert result == expected
