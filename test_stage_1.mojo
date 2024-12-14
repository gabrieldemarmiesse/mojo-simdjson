from mojo_simdjson.tests import test_stage_1


def test_simples_json():
    test_stage_1.test_simples_json()


def test_simple_strings():
    test_stage_1.test_simple_strings()

def test_escaping():
    test_stage_1.test_escaping()


def test_escaping_very_long():
    test_stage_1.test_escaping_very_long()


def main():
    #test_simples_json()
    #test_simple_strings()
    #test_escaping()
    test_escaping_very_long()